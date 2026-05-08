create or replace function public.reject_past_journey_date()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.journey_date < current_date then
    raise exception 'Cannot book a train for a past date';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_reject_past_journey_date on public.bookings;
create trigger trg_reject_past_journey_date
before insert or update on public.bookings
for each row execute function public.reject_past_journey_date();

drop trigger if exists trg_set_booking_defaults on public.bookings;
create trigger trg_set_booking_defaults
before insert on public.bookings
for each row execute function public.set_booking_defaults();