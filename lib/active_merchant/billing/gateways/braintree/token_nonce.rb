module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TokenNonce #:nodoc:
      include PostsData

      attr_reader :braintree_gateway, :options

      ACH_MANDATE = 'By clicking ["Checkout"], I authorize Braintree, a service of PayPal, ' \
        'on behalf of [your business name here] (i) to verify my bank account information ' \
        'using bank information and consumer reports and (ii) to debit my bank account.'

      def initialize(gateway, options = {})
        @braintree_gateway = gateway
        @options = options
      end

      def create_token_nonce_for_payment_method(payment_method)
        url = 'https://payments.sandbox.braintree-api.com/graphql'
        headers = {
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{client_token}",
          'Content-Type' => 'application/json',
          'Braintree-Version' => '2018-05-10'
        }
        resp = ssl_post(url, build_nonce_request(payment_method), headers)
        parse_response = JSON.parse(resp)
        parse_response.dig('data', 'tokenizeUsBankAccount', 'paymentMethod', 'id')
      end

      def client_token
        base64_token = @braintree_gateway.client_token.generate
        JSON.parse(Base64.decode64(base64_token))['authorizationFingerprint']
      end

      private

      def graphql_query
        <<-GRAPHQL
        mutation TokenizeUsBankAccount($input: TokenizeUsBankAccountInput!) {
          tokenizeUsBankAccount(input: $input) {
            paymentMethod {
              id
              details {
                ... on UsBankAccountDetails {
                  last4
                }
              }
            }
          }
        }
        GRAPHQL
      end

      def billing_address_from_options
        return nil if options[:billing_address].blank?

        address = options[:billing_address]

        {
          streetAddress: address[:address1],
          extendedAddress: address[:address2],
          city: address[:city],
          state: address[:state],
          zipCode: address[:zip]
        }.compact
      end

      def build_nonce_request(payment_method)
        input = {
          usBankAccount: {
            achMandate: ACH_MANDATE,
            routingNumber: payment_method.routing_number,
            accountNumber: payment_method.account_number,
            accountType: payment_method.account_type.upcase,
            billingAddress: billing_address_from_options
          }
        }

        if payment_method.account_holder_type == 'personal'
          input[:usBankAccount][:individualOwner] = {
            firstName: payment_method.first_name,
            lastName: payment_method.last_name
          }
        else
          input[:usBankAccount][:businessOwner] = {
            businessName: payment_method.name
          }
        end

        {
          clientSdkMetadata: {
            platform: 'web',
            source: 'client',
            integration: 'custom',
            sessionId: SecureRandom.uuid,
            version: '3.83.0'
          },
          query: graphql_query,
          variables: {
            input: input
          }
        }.to_json
      end
    end
  end
end
