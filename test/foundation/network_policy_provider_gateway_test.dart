import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkPolicyProviderGateway', () {
    test('passes proxy policy decisions through request context', () async {
      final DeterministicNetworkPolicyStore policyStore =
          DeterministicNetworkPolicyStore();
      await policyStore.storeRules(
        policyId: defaultProviderGatewayNetworkPolicyId,
        rules: <StoredNetworkPolicyRuleRecord>[
          StoredNetworkPolicyRuleRecord(
            id: 'proxy-rule',
            policyId: defaultProviderGatewayNetworkPolicyId,
            order: 1,
            matcherKind: StoredNetworkPolicyMatcherKind.domainSuffix,
            pattern: 'example.test',
            action: StoredNetworkPolicyAction.proxyTag,
            proxyTag: 'http://127.0.0.1:7890',
          ),
        ],
      );
      final DeterministicProviderGateway delegate =
          DeterministicProviderGateway(
              storage: DeterministicStorageFoundation());
      final NetworkPolicyProviderGateway gateway = NetworkPolicyProviderGateway(
        delegate: delegate,
        networkPolicyStore: policyStore,
      );
      await gateway.registerProvider(_registration);

      String? capturedProxyUrl;
      final ProviderGatewayResponse<String> response =
          await gateway.execute<String>(
        ProviderGatewayRequest<String>(
          key: _requestKey,
          load: () async => 'missing-context',
          loadWithContext: (ProviderGatewayRequestContext context) async {
            capturedProxyUrl = context.proxyUrl;
            return 'loaded';
          },
          networkPolicyUri: Uri.parse('https://example.test/rss.xml'),
        ),
      );

      expect(response.value, 'loaded');
      expect(capturedProxyUrl, 'http://127.0.0.1:7890');
      expect(
        (await policyStore.evaluationsForProvider(_providerId.value))
            .single
            .action,
        StoredNetworkPolicyAction.proxyTag,
      );
    });

    test('blocks denied requests before running the loader', () async {
      final DeterministicNetworkPolicyStore policyStore =
          DeterministicNetworkPolicyStore();
      await policyStore.storeRules(
        policyId: defaultProviderGatewayNetworkPolicyId,
        rules: <StoredNetworkPolicyRuleRecord>[
          StoredNetworkPolicyRuleRecord(
            id: 'block-rule',
            policyId: defaultProviderGatewayNetworkPolicyId,
            order: 1,
            matcherKind: StoredNetworkPolicyMatcherKind.domainSuffix,
            pattern: 'example.test',
            action: StoredNetworkPolicyAction.block,
          ),
        ],
      );
      final NetworkPolicyProviderGateway gateway = NetworkPolicyProviderGateway(
        delegate: DeterministicProviderGateway(
          storage: DeterministicStorageFoundation(),
        ),
        networkPolicyStore: policyStore,
      );
      await gateway.registerProvider(_registration);

      bool loaderCalled = false;

      await expectLater(
        gateway.execute<String>(
          ProviderGatewayRequest<String>(
            key: _requestKey,
            load: () async {
              loaderCalled = true;
              return 'loaded';
            },
            networkPolicyUri: Uri.parse('https://example.test/rss.xml'),
          ),
        ),
        throwsA(
          isA<ProviderFailure>().having(
            (ProviderFailure failure) => failure.kind,
            'kind',
            ProviderFailureKind.terminal,
          ),
        ),
      );
      expect(loaderCalled, isFalse);
      expect(
        (await policyStore.blockOutcomesForProvider(_providerId.value))
            .single
            .failureKind,
        NetworkPolicyFailureKind.blockedHost,
      );
    });
  });
}

const ProviderId _providerId = ProviderId('gateway-test-provider');
const ProviderRequestKey _requestKey = ProviderRequestKey(
  providerId: _providerId,
  cacheKey: 'feed:one',
);
const ProviderRegistration _registration = ProviderRegistration(
  providerId: _providerId,
  ratePolicy: ProviderRatePolicy(
    maxRequests: 10,
    window: Duration(minutes: 1),
  ),
  retryPolicy: ProviderRetryPolicy(
    maxAttempts: 1,
    initialBackoff: Duration.zero,
  ),
);
