-- PAMERIN — migrasi penilaian siswa
-- Jalankan di Supabase SQL Editor SETELAH schema.sql (sekali saja).

-- 1. Izinkan judge_id kosong (siswa tidak punya akun) + kolom identitas penilai
alter table public.assessments alter column judge_id drop not null;
alter table public.assessments add column reviewer_type text not null default 'guru' check (reviewer_type in ('guru','siswa'));
alter table public.assessments add column reviewer_name text;
alter table public.assessments add column reviewer_kelas text;

-- Catatan: constraint unique (poster_id, judge_id) SENGAJA tidak dihapus.
-- Di Postgres NULL dianggap berbeda, jadi banyak nilai siswa (judge_id NULL)
-- tetap bisa masuk, sedangkan 1 guru tetap hanya bisa 1x nilai per poster
-- dan upsert di judge/assessment.html tetap jalan.

-- 2. Izinkan siswa (tanpa login) mengirim nilai — hanya sebagai 'siswa'
create policy "siswa insert assessments" on public.assessments
  for insert to anon, authenticated
  with check (reviewer_type = 'siswa' and judge_id is null);

-- 3. Skor publik dipisah guru/siswa lewat view (tanpa membuka tabel assessments).
-- Kolom baru ditambahkan di akhir supaya index.html (jumlah, rata_rata) tetap jalan.
create or replace view poster_scores as
  select a.poster_id,
         count(*)::int as jumlah,
         round(avg(a.nilai), 2) as rata_rata,
         count(*) filter (where a.reviewer_type = 'guru')::int as jumlah_guru,
         round(avg(a.nilai) filter (where a.reviewer_type = 'guru'), 2) as rata_guru,
         count(*) filter (where a.reviewer_type = 'siswa')::int as jumlah_siswa,
         round(avg(a.nilai) filter (where a.reviewer_type = 'siswa'), 2) as rata_siswa
  from assessments a
  where (select ranking_published from event_settings where id = 1)
  group by a.poster_id;
grant select on poster_scores to anon, authenticated;
