  -- 완료된 주문의 금액이 0 이하면 잘못된 데이터
  -- 결과가 1행이라도 나오면 테스트 실패
  SELECT *
  FROM {{ ref('stg_orders') }}
  WHERE order_status = 'completed'
    AND order_amount <= 0