require 'spec_helper'
require 'rest-client'
require 'mockserver-client'
require 'swagger_helper'

module RestClient
    module AbstractResponse
        def status
            code
        end

        def content_type
            headers[:content_type]
        end
    end 
end

class MoviesServer
    include MockServer
    include MockServer::Model::DSL 
    extend MockServer::Model::DSL

    def initialize
        server_host = ENV.fetch("MOCK_SERVER_HOST", 'localhost')
        server_port = ENV.fetch("MOCK_SERVER_PORT", 1080)

        @mock_client = MockServer::MockServerClient.new(server_host, server_port)
    end

    def call(test)
        @mock_client.reset

        exp = expectation do |exp|
            exp.request do |request|
                request.method = 'GET'
                request.path = '/movies'
                request.headers << header('Accept', 'application/json')
                request.query_string_parameters = test.query_string_parameters
            end
        
            exp.response do |response|
                response.status_code = 200
                response.headers << header('Content-Type', 'application/json; charset=utf-8')
                response.body = body(test.movies_resp_body)
            end
        end

        @mock_client.register(exp)
    end
end

RSpec.describe "ApiServer", type: :request, capture_examples: true do 

    let(:api_server_host) { "http://#{ENV.fetch("API_SERVICE_ADDR", '127.0.0.1:8000')}" }

    describe "GET /ping" do
        let(:response) { RestClient.get "#{api_server_host}/ping" }

        describe 'swagger_docs' do
            path '/ping' do
                operation "GET", summary: "respond 200 OK" do
                    response 200, description: "successful" do
                        it do
                            expect(response.code).to eql 200
                            expect(response.body).to eql 'OK'
                        end
                    end
                end
            end
        end

        it do
            expect(response.code).to eql 200
            expect(response.body).to eql 'OK'
        end
    end

    describe "GET /movies" do
        let(:query_string_parameters) { [] }
        let(:movies_resp_body) { '[]' }

        shared_examples 'response_ok' do
            it do
                expect(response.code).to eql 200
                expect(response.body).to eql(resp_body)
            end
        end

        let(:params) { {} }
        subject(:response) { RestClient.get "#{api_server_host}/movies", {params: params} }
        
        before do
            MoviesServer.new.call(self)
        end

        describe 'swagger_docs' do
            let(:movies_resp_body) { File.read('spec/fixtures/movies.json') }
            path '/movies' do
                operation "GET", summary: "respond 200 OK" do
                    parameter :rating, in: :query, type: :string, required: false, description: "filter by rating"
                    response 200, description: "successful" do
                        schema(
                            type: :array,
                            items: {
                                type: :string,
                            }
                        )
                    end
                end
            end
        end

        context '?rating=X' do
            let(:params) { {rating: 90} }
            let(:query_string_parameters) { [MoviesServer.parameter('rating', '90')] }
            let(:movies_resp_body) { File.read('spec/fixtures/movies_90.json') }
            let(:resp_body) { movies_resp_body }
            
            include_examples 'response_ok'
        end

        describe 'set default filter' do
            let(:query_string_parameters) { [MoviesServer.parameter('rating', '70')] }
            let(:movies_resp_body) { File.read('spec/fixtures/movies.json') }
            let(:resp_body) { movies_resp_body }

            include_examples 'response_ok'
        end
    end

end 