-- PAMERIN — jalankan di Supabase SQL Editor (sekali)
create type user_role as enum ('admin', 'judge');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role user_role not null default 'judge',
  active boolean not null default false,
  created_at timestamptz default now()
);

create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, full_name, role, active)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)), 'judge', false);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

create table participants (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  kelas text not null,
  nis text,
  created_at timestamptz default now()
);

create sequence poster_seq start 1;

create table posters (
  id uuid primary key default gen_random_uuid(),
  kode text unique not null default 'P' || lpad(nextval('poster_seq')::text, 3, '0'),
  participant_id uuid references participants(id) on delete set null,
  judul text not null,
  deskripsi text,
  tujuan text,
  informasi text,
  sumber text,
  image_url text,
  storage_path text,
  status text not null default 'published' check (status in ('draft','published')),
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_posters_kode on posters(kode);

create table assessments (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references posters(id) on delete cascade,
  -- referensi ke profiles (bukan auth.users) supaya laporan admin bisa join nama penilai
  judge_id uuid not null references profiles(id) on delete cascade,
  s1 smallint not null check (s1 between 1 and 5),
  s2 smallint not null check (s2 between 1 and 5),
  s3 smallint not null check (s3 between 1 and 5),
  s4 smallint not null check (s4 between 1 and 5),
  skor smallint generated always as (s1+s2+s3+s4) stored,
  nilai numeric(5,2) generated always as ((s1+s2+s3+s4)/20.0*100) stored,
  kritik_saran text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (poster_id, judge_id)
);
create index idx_assess_poster on assessments(poster_id);
create index idx_assess_judge on assessments(judge_id);

create table event_settings (
  id int primary key default 1 check (id = 1),
  nama_acara text default 'Pameran Kokurikuler',
  tanggal date default '2026-11-20',
  lokasi text default '',
  deskripsi text default '',
  ranking_published boolean default false,
  updated_at timestamptz default now()
);
insert into event_settings (id) values (1);

-- Helper
create or replace function is_admin() returns boolean language sql security definer stable as $$
  select exists(select 1 from profiles where id = auth.uid() and role = 'admin' and active = true);
$$;
create or replace function is_active_user() returns boolean language sql security definer stable as $$
  select exists(select 1 from profiles where id = auth.uid() and active = true);
$$;

-- Skor agregat untuk halaman publik (ranking & statistik beranda).
-- View ini jalan dengan hak pemilik sehingga tidak kena RLS, tapi hanya
-- mengeluarkan rata-rata per poster (tanpa nama penilai / kritik) dan
-- hanya terisi setelah admin mencentang "publikasikan ranking".
create view poster_scores as
  select a.poster_id,
         count(*)::int as jumlah,
         round(avg(a.nilai), 2) as rata_rata
  from assessments a
  where (select ranking_published from event_settings where id = 1)
  group by a.poster_id;
grant select on poster_scores to anon, authenticated;

-- RLS
alter table profiles enable row level security;
alter table participants enable row level security;
alter table posters enable row level security;
alter table assessments enable row level security;
alter table event_settings enable row level security;

create policy "own profile" on profiles for select using (auth.uid() = id);
create policy "admin read profiles" on profiles for select using (is_admin());
create policy "admin update profiles" on profiles for update using (is_admin());

create policy "public read participants" on participants for select using (true);
create policy "admin manage participants" on participants for all using (is_admin()) with check (is_admin());

create policy "public read published posters" on posters for select using (status = 'published' or is_admin());
create policy "admin manage posters" on posters for all using (is_admin()) with check (is_admin());

create policy "judge own assessments" on assessments for select using (judge_id = auth.uid());
create policy "admin read assessments" on assessments for select using (is_admin());
create policy "judge insert own" on assessments for insert with check (judge_id = auth.uid() and is_active_user());
create policy "judge update own" on assessments for update using (judge_id = auth.uid() and is_active_user());
create policy "admin manage assessments" on assessments for all using (is_admin()) with check (is_admin());

create policy "public read settings" on event_settings for select using (true);
create policy "admin update settings" on event_settings for update using (is_admin());

-- Storage bucket
insert into storage.buckets (id, name, public) values ('posters','posters',true)
on conflict (id) do nothing;

create policy "public read posters bucket" on storage.objects for select using (bucket_id = 'posters');
create policy "admin upload posters" on storage.objects for insert with check (bucket_id = 'posters' and is_admin());
create policy "admin update posters" on storage.objects for update using (bucket_id = 'posters' and is_admin());
create policy "admin delete posters" on storage.objects for delete using (bucket_id = 'posters' and is_admin());
