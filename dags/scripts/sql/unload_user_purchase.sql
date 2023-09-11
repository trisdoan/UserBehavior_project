COPY (
       select invoice_number,
              stock_code,
              detail,
              quantity,
              invoice_date,
              unit_price,
              customer_id,
              country
       from retail.user_purchase 
) TO '{{ params.user_purchase }}' WITH (FORMAT CSV, HEADER);