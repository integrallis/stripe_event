module FixtureHelper
  def stub_event(identifier, status = 200)
    stub_request(:get, "https://api.stripe.com/v1/events/#{identifier}").
      to_return(status: status, body: get_fixture(identifier), headers: {})
  end

  def get_fixture(name)
    File.read("spec/support/fixtures/#{name}.json")
  end
end
