require 'test_helper'

class RemoteBraintreeTokenNonceTest < Test::Unit::TestCase
  def setup
    @gateway = BraintreeGateway.new(fixtures(:braintree_blue))
    @braintree_backend = @gateway.instance_eval { @braintree_gateway }
    @generator = TokenNonce.new(@braintree_backend)
  end

  def test_client_token_generation
    token = @generator.client_token
    assert_not_nil token
  end

  def test_successfully_create_token_nonce_for_bank_account
    bank_account = check({ account_number: '4012000033330125', routing_number: '011000015' })
    tokenized_bank_account = @generator.create_token_nonce_for_payment_method(bank_account)
    assert_not_nil tokenized_bank_account
    assert_match %r(^tokenusbankacct_), tokenized_bank_account
  end

  def test_url_generation
    config_base = {
      merchant_id: 'test',
      public_key: 'test',
      private_key: 'test',
      environment: :sandbox
    }

    configuration = Braintree::Configuration.new(config_base)
    braintree_backend = Braintree::Gateway.new(configuration)
    generator = TokenNonce.new(braintree_backend)

    assert_equal 'https://payments.sandbox.braintree-api.com/graphql', generator.url

    configuration = Braintree::Configuration.new(config_base.update(environment: :production))
    braintree_backend = Braintree::Gateway.new(configuration)
    generator = TokenNonce.new(braintree_backend)

    assert_equal 'https://payments.braintree-api.com/graphql', generator.url
  end
end
