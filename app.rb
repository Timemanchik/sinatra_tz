# frozen_string_literal: true

require_relative './constants'
require_relative 'validations/submit'
require_relative 'validations/operation'
require_relative 'lib/operation'
require 'json-schema'
require 'sinatra/base'
require 'sequel'
require 'sqlite3'
require 'json'
require 'pry'

class App < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :raise_errors, false
  set :show_exceptions, false
  include Validations::Submit
  include Validations::Operation
  include Lib::Operation
  include Constants

  DB = Sequel.connect('sqlite://db/test.db')

  users = DB[:user]
  operations = DB[:operation]
  products = DB[:product]
  templates = DB[:template]

  before do
    content_type :json
    if request.request_method == 'POST'
      body_parameters = request.body.read
      params.merge!(JSON.parse(body_parameters))
    end
  end

  error 404 do
    "#{request.request_method} #{request.path}"
  end

  post '/submit' do
    user = users.where(id: params.dig(:user, :id)).first
    operation = operations.where(id: params[:operation_id], user_id: params.dig(:user, :id)).first
    submit_validate!(user, operation, params)

    begin
      DB.transaction do
        operations.where(id: params[:operation_id], user_id: params
                  .dig(:user, :id))
                  .update(done: true,
                          write_off: params[:write_off],
                          check_summ: operation[:check_summ] - params[:write_off])

        @operation_new = operations.where(id: params[:operation_id], user_id: params
                                   .dig(:user, :id))
                                   .first
        users.where(id: params
             .dig(:user, :id))
             .update(bonus: user[:bonus] - @operation_new[:write_off] + @operation_new[:cashback])
      end
    rescue Sequel::DatabaseError => e
      halt(500, e.message)
    end

    {
      status: response.status,
      message: DATA_PROCESSED_SUCCESSFULLY,
      operation: {
        user_id: params.dig(:user, :id),
        cashback: @operation_new[:cashback].to_i,
        cashback_percent: @operation_new[:cashback_percent].to_i,
        discount: @operation_new[:discount].to_f,
        discount_percent: @operation_new[:discount_percent].to_f,
        write_off: @operation_new[:write_off].to_i,
        check_summ: @operation_new[:check_summ].to_i
      }
    }.to_json
  end

  post '/operation' do
    user = users.where(id: params[:user_id]).first
    operation_validate!(user, products, params)

    begin
      operation_id = operations.insert(
        user_id: params[:user_id],
        cashback: cashback_will_add(products, templates, user),
        cashback_percent: cashback_value(products, templates, user),
        discount: total_discount_sum(products, templates, user),
        discount_percent: discount_value(products, templates, user),
        check_summ: total_summ(products, templates, user),
        allowed_write_off: allowed_summ(products, templates, user)
      )
    rescue Sequel::DatabaseError => e
      halt(500, e.message)
    end

    last_opertaion = operations.where(id: operation_id, user_id: params[:user_id]).first

    {
      status: response.status,
      user: user_payload(user),
      operation_id:,
      summ: last_opertaion[:check_summ].to_f,
      positions: positions_payload(products, templates, user),
      discount: {
        summ: last_opertaion[:discount].to_f,
        value: "#{last_opertaion[:discount_percent].to_f}%"
      },
      cashback: {
        existed_summ: user[:bonus].to_i,
        allowed_summ: last_opertaion[:allowed_write_off].to_f,
        value: "#{last_opertaion[:cashback_percent].to_f}%",
        will_add: last_opertaion[:cashback].to_i
      }
    }.to_json
  end
end
