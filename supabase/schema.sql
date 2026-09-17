-- Slotly — salon/barber booking schema
-- Paste into the Supabase SQL editor and run once.

create extension if not exists btree_gist;

create type user_role as enum ('customer', 'owner');
create type booking_status as enum ('pending', 'confirmed', 'completed', 'cancelled', 'no_show');

-- ---------------------------------------------------------------- tables

create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text not null default '',
  phone      text,
  role       user_role not null default 'customer',
  created_at timestamptz not null default now()
);

create table shops (
  id                    uuid primary key default gen_random_uuid(),
  owner_id              uuid not null references profiles(id) on delete cascade,
  name                  text not null,
  description           text,
  address               text,
  phone                 text,
  image_url             text,
  timezone              text not null default 'UTC',
  slot_interval_minutes int  not null default 15 check (slot_interval_minutes > 0),
  created_at            timestamptz not null default now()
);
create index shops_owner_idx on shops(owner_id);

create table staff (
  id        uuid primary key default gen_random_uuid(),
  shop_id   uuid not null references shops(id) on delete cascade,
  name      text not null,
  title     text,
  image_url text,
  is_active boolean not null default true
);
create index staff_shop_idx on staff(shop_id);

create table services (
  id               uuid primary key default gen_random_uuid(),
  shop_id          uuid not null references shops(id) on delete cascade,
  name             text not null,
  duration_minutes int  not null check (duration_minutes > 0),
  price_cents      int  not null check (price_cents >= 0),
  is_active        boolean not null default true
);
create index services_shop_idx on services(shop_id);

-- which barber can perform which service
create table staff_services (
  staff_id   uuid not null references staff(id) on delete cascade,
  service_id uuid not null references services(id) on delete cascade,
  primary key (staff_id, service_id)
);

-- recurring weekly availability. weekday: 0 = Sunday .. 6 = Saturday
create table working_hours (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references staff(id) on delete cascade,
  weekday    int  not null check (weekday between 0 and 6),
  start_time time not null,
  end_time   time not null,
  check (end_time > start_time)
);
create index working_hours_staff_idx on working_hours(staff_id);

-- one-off absences: holidays, lunch breaks, sick days
create table time_off (
  id        uuid primary key default gen_random_uuid(),
  staff_id  uuid not null references staff(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at   timestamptz not null,
  reason    text,
  check (ends_at > starts_at)
);
create index time_off_staff_idx on time_off(staff_id);

create table bookings (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references shops(id) on delete cascade,
  staff_id    uuid not null references staff(id) on delete cascade,
  service_id  uuid not null references services(id) on delete restrict,
  customer_id uuid not null references profiles(id) on delete cascade,
  starts_at   timestamptz not null,
  ends_at     timestamptz not null,
  status      booking_status not null default 'confirmed',
  price_cents int not null,
  notes       text,
  created_at  timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index bookings_shop_time_idx on bookings(shop_id, starts_at);
create index bookings_customer_time_idx on bookings(customer_id, starts_at);
create index bookings_staff_time_idx on bookings(staff_id, starts_at);

-- The double-booking guard. Two live bookings for the same barber can never
-- overlap in time, enforced by the database rather than by application code,
-- so two customers tapping "confirm" at the same instant cannot both win.
alter table bookings add constraint bookings_no_overlap
  exclude using gist (
    staff_id with =,
    tstzrange(starts_at, ends_at) with &&
  ) where (status in ('pending', 'confirmed'));

-- ---------------------------------------------------------------- helpers

create function public.owns_shop(p_shop_id uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from shops where id = p_shop_id and owner_id = auth.uid());
$$;

create function public.owns_staff(p_staff_id uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from staff st join shops s on s.id = st.shop_id
    where st.id = p_staff_id and s.owner_id = auth.uid()
  );
$$;

-- every new auth user gets a profile row, role taken from signup metadata
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'phone',
    coalesce((new.raw_user_meta_data ->> 'role')::user_role, 'customer')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- booking rpc

-- Clients never insert into bookings directly. This function derives the end
-- time and the price from the service row, so a tampered client cannot book a
-- $50 haircut for $1 or hold a chair for three hours.
create function public.create_booking(
  p_staff_id   uuid,
  p_service_id uuid,
  p_starts_at  timestamptz,
  p_notes      text default null
) returns bookings
language plpgsql security definer set search_path = public as $$
declare
  v_service  services;
  v_staff    staff;
  v_shop     shops;
  v_ends_at  timestamptz;
  v_local    timestamp;
  v_booking  bookings;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_service from services where id = p_service_id and is_active;
  if not found then raise exception 'service_not_found'; end if;

  select * into v_staff from staff where id = p_staff_id and is_active;
  if not found then raise exception 'staff_not_found'; end if;

  if v_staff.shop_id <> v_service.shop_id then
    raise exception 'shop_mismatch';
  end if;

  if not exists (
    select 1 from staff_services
    where staff_id = p_staff_id and service_id = p_service_id
  ) then
    raise exception 'staff_cannot_perform_service';
  end if;

  if p_starts_at < now() then
    raise exception 'slot_in_past';
  end if;

  select * into v_shop from shops where id = v_service.shop_id;
  v_ends_at := p_starts_at + make_interval(mins => v_service.duration_minutes);
  v_local   := p_starts_at at time zone v_shop.timezone;

  -- must fall inside a working_hours window for that weekday
  if not exists (
    select 1 from working_hours wh
    where wh.staff_id = p_staff_id
      and wh.weekday  = extract(dow from v_local)::int
      and v_local::time >= wh.start_time
      and (v_ends_at at time zone v_shop.timezone)::time <= wh.end_time
  ) then
    raise exception 'outside_working_hours';
  end if;

  -- must not collide with a holiday or break
  if exists (
    select 1 from time_off t
    where t.staff_id = p_staff_id
      and tstzrange(t.starts_at, t.ends_at) && tstzrange(p_starts_at, v_ends_at)
  ) then
    raise exception 'staff_unavailable';
  end if;

  insert into bookings (
    shop_id, staff_id, service_id, customer_id,
    starts_at, ends_at, price_cents, notes
  ) values (
    v_service.shop_id, p_staff_id, p_service_id, auth.uid(),
    p_starts_at, v_ends_at, v_service.price_cents, p_notes
  ) returning * into v_booking;

  return v_booking;
exception
  when exclusion_violation then
    raise exception 'slot_taken';
end;
$$;

-- ---------------------------------------------------------------- rls

alter table profiles       enable row level security;
alter table shops          enable row level security;
alter table staff          enable row level security;
alter table services       enable row level security;
alter table staff_services enable row level security;
alter table working_hours  enable row level security;
alter table time_off       enable row level security;
alter table bookings       enable row level security;

create policy profiles_read_own on profiles
  for select using (id = auth.uid());

-- a shop owner may read the profile of anyone who booked with them
create policy profiles_read_own_customers on profiles
  for select using (
    exists (
      select 1 from bookings b join shops s on s.id = b.shop_id
      where b.customer_id = profiles.id and s.owner_id = auth.uid()
    )
  );

create policy profiles_update_own on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- the catalogue is public to any signed-in user; only the owner edits it
create policy shops_read_all on shops for select using (true);
create policy shops_insert_own on shops for insert
  with check (owner_id = auth.uid());
create policy shops_update_own on shops for update
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy shops_delete_own on shops for delete using (owner_id = auth.uid());

create policy staff_read_all on staff for select using (true);
create policy staff_write_own on staff for all
  using (owns_shop(shop_id)) with check (owns_shop(shop_id));

create policy services_read_all on services for select using (true);
create policy services_write_own on services for all
  using (owns_shop(shop_id)) with check (owns_shop(shop_id));

create policy staff_services_read_all on staff_services for select using (true);
create policy staff_services_write_own on staff_services for all
  using (owns_staff(staff_id)) with check (owns_staff(staff_id));

create policy working_hours_read_all on working_hours for select using (true);
create policy working_hours_write_own on working_hours for all
  using (owns_staff(staff_id)) with check (owns_staff(staff_id));

create policy time_off_read_all on time_off for select using (true);
create policy time_off_write_own on time_off for all
  using (owns_staff(staff_id)) with check (owns_staff(staff_id));

-- customers see their own bookings, owners see everything in their shop
create policy bookings_read_own on bookings
  for select using (customer_id = auth.uid() or owns_shop(shop_id));
create policy bookings_update_own on bookings
  for update using (customer_id = auth.uid() or owns_shop(shop_id))
  with check (customer_id = auth.uid() or owns_shop(shop_id));
create policy bookings_delete_owner on bookings
  for delete using (owns_shop(shop_id));
-- no insert policy on purpose: bookings are created through create_booking()
