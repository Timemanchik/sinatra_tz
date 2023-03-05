module Validation
  CUSTOMER_NOT_FOUND = 'клиент не найден!'
  OPERATION_NOT_FOUND = 'Операция не найдена!'
  OPERATION_COMPLETED = 'Операция уже проведена!'
  NOT_ENOUGH_POINTS = 'Недостаточно баллов для списания!'

  def db_validations_for_submit(user, operation)
    halt(403, CUSTOMER_NOT_FOUND) if user.nil?
    halt(403, OPERATION_NOT_FOUND) if operation.nil?
    halt(403, OPERATION_COMPLETED) if operation[:done]
    halt(403, NOT_ENOUGH_POINTS) if params[:write_off] > operation[:allowed_write_off]
  end

  def db_validations_for_operation(user, products)
    halt(403, CUSTOMER_NOT_FOUND) if user.nil?
    product_object_list = params[:positions].map {products.where(id: _1[:id]).first}
    unless product_object_list.all?
      halt(403, "Товар c id = #{params[:positions][product_object_list.index(nil)][:id]} не найден!")
    end
  end
end