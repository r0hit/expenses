-- Household expenses: database setup
-- Paste this whole file into Supabase > SQL Editor and click Run.
-- Safe to run once on a new project.

-- ---------- Tables ----------
create table public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 60),
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
  salary      numeric(12,2) not null default 0 check (salary >= 0),
  goal        numeric(5,2)  not null default 10 check (goal between 0 and 90),
  currency    text not null default 'USD' check (currency in ('USD','EUR','GBP','INR','CAD')),
  created_at  timestamptz not null default now()
);

create table public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  joined_at    timestamptz not null default now(),
  primary key (household_id, user_id)
);
create index household_members_user_idx on public.household_members (user_id);

create table public.expenses (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  amount       numeric(12,2) not null check (amount > 0),
  category     text not null check (category in ('mortgage','car','utilities','groceries','transport','health','food','shopping','subscriptions','entertainment','other','savings','investments')),
  spent_on     date not null,
  note         text not null default '' check (char_length(note) <= 200),
  created_by   uuid default auth.uid() references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index expenses_household_date_idx on public.expenses (household_id, spent_on desc);

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

create trigger expenses_touch before update on public.expenses
for each row execute function public.touch_updated_at();

-- ---------- Membership check (used by every policy) ----------
create or replace function public.is_member(h uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.household_members
    where household_id = h and user_id = auth.uid()
  );
$$;

-- ---------- Row-level security: only household members see anything ----------
alter table public.households        enable row level security;
alter table public.household_members enable row level security;
alter table public.expenses          enable row level security;

create policy "members read household"   on public.households for select to authenticated using (public.is_member(id));
create policy "members update household" on public.households for update to authenticated using (public.is_member(id)) with check (public.is_member(id));

create policy "members read members"     on public.household_members for select to authenticated using (public.is_member(household_id));
create policy "update own member name"   on public.household_members for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "leave household"          on public.household_members for delete to authenticated using (user_id = auth.uid());

create policy "members read expenses"    on public.expenses for select to authenticated using (public.is_member(household_id));
create policy "members add expenses"     on public.expenses for insert to authenticated with check (public.is_member(household_id));
create policy "members edit expenses"    on public.expenses for update to authenticated using (public.is_member(household_id)) with check (public.is_member(household_id));
create policy "members delete expenses"  on public.expenses for delete to authenticated using (public.is_member(household_id));

grant select, update                 on public.households        to authenticated;
grant select, update, delete         on public.household_members to authenticated;
grant select, insert, update, delete on public.expenses          to authenticated;

-- ---------- Create / join / invite ----------
create or replace function public.create_household(p_name text, p_display_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare hid uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  insert into public.households (name) values (trim(p_name)) returning id into hid;
  insert into public.household_members (household_id, user_id, display_name)
  values (hid, auth.uid(), trim(p_display_name));
  return hid;
end $$;

create or replace function public.join_household(p_code text, p_display_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare hid uuid; n int;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  select id into hid from public.households
  where invite_code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'));
  if hid is null then raise exception 'Invite code not found'; end if;
  select count(*) into n from public.household_members where household_id = hid;
  if n >= 6 then raise exception 'This household is full'; end if;
  insert into public.household_members (household_id, user_id, display_name)
  values (hid, auth.uid(), trim(p_display_name))
  on conflict (household_id, user_id) do update set display_name = excluded.display_name;
  return hid;
end $$;

create or replace function public.new_invite_code(p_household uuid) returns text
language plpgsql security definer set search_path = public as $$
declare code text;
begin
  if not public.is_member(p_household) then raise exception 'Not a member'; end if;
  code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  update public.households set invite_code = code where id = p_household;
  return code;
end $$;

revoke all on function public.is_member(uuid)                   from public, anon;
revoke all on function public.create_household(text, text)      from public, anon;
revoke all on function public.join_household(text, text)        from public, anon;
revoke all on function public.new_invite_code(uuid)             from public, anon;
grant execute on function public.is_member(uuid)                to authenticated;
grant execute on function public.create_household(text, text)   to authenticated;
grant execute on function public.join_household(text, text)     to authenticated;
grant execute on function public.new_invite_code(uuid)          to authenticated;

-- ---------- Live updates between phones ----------
alter publication supabase_realtime add table public.expenses, public.households, public.household_members;
