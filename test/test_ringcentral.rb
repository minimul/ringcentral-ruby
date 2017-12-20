require 'test/unit'
require 'ringcentral'
require 'dotenv'

class RingCentralTest < Test::Unit::TestCase
  def test_class_variables
    assert_equal 'https://platform.devtest.ringcentral.com', RingCentral.SANDBOX_SERVER
    assert_equal 'https://platform.ringcentral.com', RingCentral.PRODUCTION_SERVER
  end

  def test_initializer
    rc = RingCentral.new('app_key', 'app_secret', RingCentral.SANDBOX_SERVER)
    assert_equal 'app_key', rc.app_key
    assert_equal 'app_secret', rc.app_secret
    assert_equal 'https://platform.devtest.ringcentral.com', rc.server
    assert_equal true, rc.auto_refresh
  end

  def test_authorize_uri
    rc = RingCentral.new('app_key', 'app_secret', RingCentral.SANDBOX_SERVER)
    assert_equal RingCentral.SANDBOX_SERVER + '/restapi/oauth/authorize?client_id=app_secret&redirect_uri=https%3A%2F%2Fexample.com&response_type=code&state=mystate', rc.authorize_uri('https://example.com', 'mystate')
  end

  def test_password_flow
    Dotenv.load
    rc = RingCentral.new(ENV['appKey'], ENV['appSecret'], ENV['server'])
    assert_equal nil, rc.token

    # create token
    rc.authorize(username: ENV['username'], extension: ENV['extension'], password: ENV['password'])
    assert_not_equal nil, rc.token

    # refresh token
    rc.refresh
    assert_not_equal nil, rc.token

    # revoke token
    rc.revoke
    assert_equal nil, rc.token
  end

  def test_http_methods
    Dotenv.load
    rc = RingCentral.new(ENV['appKey'], ENV['appSecret'], ENV['server'])
    rc.authorize(username: ENV['username'], extension: ENV['extension'], password: ENV['password'])

    # get
    r = rc.get('/restapi/v1.0/account/~/extension/~')
    assert_not_equal nil, r
    assert_equal '101', JSON.parse(r.body)['extensionNumber']

    # post
    r = rc.post('/restapi/v1.0/account/~/extension/~/sms', payload: {
      to: [{phoneNumber: ENV['receiver']}],
      from: {phoneNumber: ENV['username']},
      text: 'Hello world'
    })
    assert_not_equal nil, r
    message = JSON.parse(r.body)
    assert_equal 'SMS', message['type']
    messageUrl = "/restapi/v1.0/account/~/extension/~/message-store/#{message['id']}"

    # put
    r = rc.put(messageUrl, payload: { readStatus: 'Unread' })
    assert_not_equal nil, r
    message = JSON.parse(r.body)
    assert_equal 'Unread', message['readStatus']
    r = rc.put(messageUrl, payload: { readStatus: 'Read' })
    assert_not_equal nil, r
    message = JSON.parse(r.body)
    assert_equal 'Read', message['readStatus']

    # delete
    r = rc.delete(messageUrl)
    assert_not_equal nil, r
    r = rc.get(messageUrl)
    assert_not_equal nil, r
    message = JSON.parse(r.body)
    assert_equal 'Deleted', message['availability']
  end
end
