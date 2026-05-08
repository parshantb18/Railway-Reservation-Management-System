create or replace function public.set_booking_defaults()
returns trigger language plpgsql
set search_path = public
as $$
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