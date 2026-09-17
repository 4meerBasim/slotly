-- Demo data for Slotly.
-- Sign up in the app first as an OWNER with the email below, then run this.

do $$
declare
  v_owner  uuid;
  v_shop   uuid;
  v_cut    uuid;
  v_fade   uuid;
  v_beard  uuid;
  v_combo  uuid;
  v_omar   uuid;
  v_kareem uuid;
  v_sami   uuid;
  v_staff  uuid;
  v_day    int;
begin
  select id into v_owner from auth.users where email = 'owner@slotly.app';
  if v_owner is null then
    raise exception 'Sign up as owner@slotly.app (role: owner) before seeding.';
  end if;

  delete from shops where owner_id = v_owner;

  insert into shops (owner_id, name, description, address, phone, timezone)
  values (
    v_owner,
    'Ironside Barbers',
    'Classic cuts, hot towel shaves, no appointment left waiting.',
    '14 Mill Street, Downtown',
    '+1 555 0142',
    'UTC'
  ) returning id into v_shop;

  insert into services (shop_id, name, duration_minutes, price_cents) values
    (v_shop, 'Haircut',            30, 2500) returning id into v_cut;
  insert into services (shop_id, name, duration_minutes, price_cents) values
    (v_shop, 'Skin Fade',          45, 3500) returning id into v_fade;
  insert into services (shop_id, name, duration_minutes, price_cents) values
    (v_shop, 'Beard Trim',         20, 1500) returning id into v_beard;
  insert into services (shop_id, name, duration_minutes, price_cents) values
    (v_shop, 'Cut + Beard',        60, 4000) returning id into v_combo;

  insert into staff (shop_id, name, title) values
    (v_shop, 'Omar Haddad',   'Master barber')  returning id into v_omar;
  insert into staff (shop_id, name, title) values
    (v_shop, 'Kareem Nasser', 'Senior barber')  returning id into v_kareem;
  insert into staff (shop_id, name, title) values
    (v_shop, 'Sami Rahal',    'Barber')         returning id into v_sami;

  -- Omar does everything, Kareem skips the combo, Sami does the quick ones.
  insert into staff_services (staff_id, service_id) values
    (v_omar, v_cut), (v_omar, v_fade), (v_omar, v_beard), (v_omar, v_combo),
    (v_kareem, v_cut), (v_kareem, v_fade), (v_kareem, v_beard),
    (v_sami, v_cut), (v_sami, v_beard);

  -- Tue–Sat 09:00–18:00 for everyone, plus Omar on Monday afternoons.
  foreach v_staff in array array[v_omar, v_kareem, v_sami] loop
    for v_day in 2..6 loop
      insert into working_hours (staff_id, weekday, start_time, end_time)
      values (v_staff, v_day, '09:00', '18:00');
    end loop;
  end loop;

  insert into working_hours (staff_id, weekday, start_time, end_time)
  values (v_omar, 1, '13:00', '18:00');

  -- Kareem takes a long lunch every day this week.
  insert into time_off (staff_id, starts_at, ends_at, reason)
  select
    v_kareem,
    (current_date + i) + time '12:30',
    (current_date + i) + time '13:30',
    'Lunch'
  from generate_series(0, 6) as i;

  raise notice 'Seeded Ironside Barbers with 4 services and 3 barbers.';
end $$;
