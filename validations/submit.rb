# frozen_string_literal: true

require_relative '../constants'

module Validations
  module Submit
    include Constants

    def submit_validate!(user, operation, params)
      submit_params_validate!(params)
      submit_db_validate!(user, operation, params)
    end

    private

    def submit_params_validate!(params)
      JSON::Validator.validate!('./request_schemas/submit.json', params)
    rescue JSON::Schema::ValidationError => e
      halt(403, e.message)
    end

    def submit_db_validate!(user, operation, params)
      halt(403, CUSTOMER_NOT_FOUND) if user.nil?
      halt(403, OPERATION_NOT_FOUND) if operation.nil?
      halt(403, OPERATION_COMPLETED) if operation[:done]
      halt(403, NOT_ENOUGH_POINTS) if params[:write_off] > operation[:allowed_write_off]
    end
  end
end
