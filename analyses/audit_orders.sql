  {% set old_relation = ref('fct_orders_daily') %}
  {% set new_relation = ref('fct_orders_daily') %}

  {{ audit_helper.compare_relations(
      a_relation = old_relation,
      b_relation = new_relation,
      primary_key = 'order_region_key'
  ) }}