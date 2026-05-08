
create table public.stations (
  code text primary key,
  name text not null,
  city text not null,
  created_at timestamptz not null default now()
);

create table public.trains (
  id bigint generated always as identity primary key,
  name text not null,
  type text not null,
  from_code text not null references public.stations(code),
  to_code text not null references public.stations(code),
  dep_time text not null,
  arr_time text not null,
  total_seats int not null default 500,
  created_at timestamptz not null default now()
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  train_id bigint not null references public.trains(id),
  journey_date date not null,
  passenger_name text not null,
  seat text not null,
  pnr text not null unique,
  status text not null default 'CONFIRMED',
  created_at timestamptz not null default now()
);

alter table public.stations enable row level security;
alter table public.trains enable row level security;
alter table public.bookings enable row level security;

create policy "Public read stations" on public.stations for select using (true);
create policy "Public read trains" on public.trains for select using (true);

create policy "Users view own bookings" on public.bookings for select using (auth.uid() = user_id);
create policy "Users create own bookings" on public.bookings for insert with check (auth.uid() = user_id);
create policy "Users cancel own bookings" on public.bookings for update using (auth.uid() = user_id);

create or replace function public.set_booking_defaults()
returns trigger language plpgsql as $$
declare
  new_pnr text;
  new_seat text;
begin
  if new.pnr is null or new.pnr = '' then
    loop
      new_pnr := lpad((floor(random()*9000000000) + 1000000000)::bigint::text, 10, '0');
      exit when not exists (select 1 from public.bookings where pnr = new_pnr);
    end loop;
    new.pnr := new_pnr;
  end if;
  if new.seat is null or new.seat = '' then
    new_seat := 'S' || (floor(random()*10)+1)::int || '-' || (floor(random()*72)+1)::int;
    new.seat := new_seat;
  end if;
  return new;
end;
$$;

create trigger trg_set_booking_defaults
before insert on public.bookings
for each row execute function public.set_booking_defaults();
