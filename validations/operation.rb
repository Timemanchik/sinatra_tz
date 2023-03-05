# frozen_string_literal: true

require_relative '../constants'

module Validations
  module Operation
    include Constants

    def operation_validate!(user, products, params)
      operation_params_validate!(params)
      operation_db_validate!(user, products, params)
    end

    private

    def operation_params_validate!(params)
      JSON::Validator.validate!('./request_schemas/operation.json', params)
    rescue JSON::Schema::ValidationError => e
      halt(403, e.message)
    end

    def operation_db_validate!(user, products, params)
      halt(403, CUSTOMER_NOT_FOUND) if user.nil?
      product_object_list = params[:positions].map { products.where(id: _1[:id]).first }
      return if product_object_list.all?

      halt(403, "Товар c id = #{params[:positions][product_object_list.index(nil)][:id]} не найден!")
    end
  end
end
