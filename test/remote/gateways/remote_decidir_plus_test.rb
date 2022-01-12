require 'test_helper'
require 'securerandom'

class RemoteDecidirPlusTest < Test::Unit::TestCase
  def setup
    @gateway = DecidirPlusGateway.new(fixtures(:decidir_plus))

    @amount = 100
    @credit_card = credit_card('4484590159923090')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.store(@credit_card)

    response = @gateway.purchase(@amount, @credit_card, @options.merge(payment_id: response.authorization))
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_failed_purchase
    assert response = @gateway.store(@credit_card)

    response = @gateway.purchase(@amount, @declined_card, @options.merge(payment_id: response.authorization))
    assert_failure response
    assert_equal 'invalid_param: bin', response.message
  end

  def test_successful_refund
    response = @gateway.store(@credit_card)

    purchase = @gateway.purchase(@amount, @credit_card, @options.merge(payment_id: response.authorization))
    assert_success purchase
    assert_equal 'approved', purchase.message

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'approved', refund.message
  end

  def test_partial_refund
    assert response = @gateway.store(@credit_card)

    purchase = @gateway.purchase(@amount, @credit_card, @options.merge(payment_id: response.authorization))
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'not_found_error', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'active', response.message
    assert_equal @credit_card.number[0..5], response.authorization.split('|')[1]
  end

  def test_invalid_login
    gateway = DecidirPlusGateway.new(public_key: '12345', private_key: 'abcde')

    response = gateway.store(@credit_card, @options)
    assert_failure response
    assert_match %r{Invalid authentication credentials}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:public_key], transcript)
    assert_scrubbed(@gateway.options[:private_key], transcript)
  end
end
