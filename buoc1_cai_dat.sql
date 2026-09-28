-- =====================================================================
-- MÀN HÌNH THEO DÕI CÔNG TÁC TUYÊN GIÁO - CÀI ĐẶT CƠ SỞ DỮ LIỆU (BƯỚC 1)
-- Chạy toàn bộ file này một lần trong Supabase > SQL Editor.
-- Chạy lại nhiều lần vẫn an toàn.
-- =====================================================================

-- 1. BẢNG ------------------------------------------------------------
create table if not exists public.quyen (
  user_id uuid primary key references auth.users(id) on delete cascade,
  vai_tro text not null check (vai_tro in ('quan_tri', 'xem')),
  ghi_chu text
);

create table if not exists public.ky_bao_cao (
  id        uuid primary key default gen_random_uuid(),
  ma        text not null unique,              -- vd: 2026-T09, 2026-Q3, 2026-6T, 2026-9T, 2026-N
  ten       text not null,                     -- vd: Tháng 9 năm 2026
  loai      text not null check (loai in ('thang', 'quy', '6t', '9t', 'nam')),
  so        smallint,
  nam       smallint not null,
  thu_tu    smallint not null,                 -- tháng kết thúc kỳ, dùng để sắp xếp
  dang_hien boolean not null default false,    -- kỳ đang hiện trên màn hình
  ngay_tai  timestamptz not null default now()
);
create unique index if not exists ky_bao_cao_mot_ky_hien
  on public.ky_bao_cao (dang_hien) where dang_hien;

create table if not exists public.chi_so (
  ky_id       uuid not null references public.ky_bao_cao(id) on delete cascade,
  ma_chi_tieu text not null,
  gia_tri     numeric not null,
  primary key (ky_id, ma_chi_tieu)
);

create table if not exists public.tin_noi_bat (
  id       bigint generated always as identity primary key,
  noi_dung text not null,
  thu_tu   int not null default 0,
  hien     boolean not null default true,
  ngay_tao timestamptz not null default now()
);

create table if not exists public.anh_trinh_chieu (
  id         bigint generated always as identity primary key,
  duong_dan  text not null,                    -- đường dẫn trong bucket anh-trinh-chieu
  dia_phuong text not null,
  noi_dung   text,
  nguon      text,
  thu_tu     int not null default 0,
  hien       boolean not null default true,
  ngay_tao   timestamptz not null default now()
);

-- 2. HÀM PHÂN QUYỀN -------------------------------------------------
create or replace function public.vai_tro_hien_tai()
returns text language sql stable security definer set search_path = public as $$
  select vai_tro from public.quyen where user_id = auth.uid()
$$;

create or replace function public.la_quan_tri()
returns boolean language sql stable set search_path = public as $$
  select coalesce(public.vai_tro_hien_tai() = 'quan_tri', false)
$$;

create or replace function public.co_quyen_xem()
returns boolean language sql stable set search_path = public as $$
  select coalesce(public.vai_tro_hien_tai() in ('quan_tri', 'xem'), false)
$$;

-- 3. KHÓA DỮ LIỆU (ROW LEVEL SECURITY) ------------------------------
alter table public.quyen           enable row level security;
alter table public.ky_bao_cao      enable row level security;
alter table public.chi_so          enable row level security;
alter table public.tin_noi_bat     enable row level security;
alter table public.anh_trinh_chieu enable row level security;

drop policy if exists quyen_doc_cua_minh on public.quyen;
create policy quyen_doc_cua_minh on public.quyen
  for select to authenticated using (user_id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['ky_bao_cao', 'chi_so', 'tin_noi_bat', 'anh_trinh_chieu'] loop
    execute format('drop policy if exists %1$s_xem on public.%1$s', t);
    execute format('drop policy if exists %1$s_them on public.%1$s', t);
    execute format('drop policy if exists %1$s_sua on public.%1$s', t);
    execute format('drop policy if exists %1$s_xoa on public.%1$s', t);
    execute format('create policy %1$s_xem on public.%1$s for select to authenticated using (public.co_quyen_xem())', t);
    execute format('create policy %1$s_them on public.%1$s for insert to authenticated with check (public.la_quan_tri())', t);
    execute format('create policy %1$s_sua on public.%1$s for update to authenticated using (public.la_quan_tri()) with check (public.la_quan_tri())', t);
    execute format('create policy %1$s_xoa on public.%1$s for delete to authenticated using (public.la_quan_tri())', t);
  end loop;
end $$;

-- 4. HÀM LƯU KỲ BÁO CÁO VÀ CHỌN KỲ HIỂN THỊ ------------------------
create or replace function public.chon_ky_hien(p_ky uuid)
returns void language plpgsql set search_path = public as $$
begin
  if not public.la_quan_tri() then
    raise exception 'Tài khoản không có quyền quản trị';
  end if;
  update public.ky_bao_cao set dang_hien = false where dang_hien and id <> p_ky;
  update public.ky_bao_cao set dang_hien = true where id = p_ky;
end $$;

create or replace function public.luu_ky_bao_cao(
  p_ma text, p_ten text, p_loai text, p_so int, p_nam int, p_thu_tu int,
  p_hien boolean, p_chi_so jsonb
) returns uuid language plpgsql set search_path = public as $$
declare v_id uuid;
begin
  if not public.la_quan_tri() then
    raise exception 'Tài khoản không có quyền quản trị';
  end if;
  insert into public.ky_bao_cao (ma, ten, loai, so, nam, thu_tu)
  values (p_ma, p_ten, p_loai, p_so, p_nam, p_thu_tu)
  on conflict (ma) do update
    set ten = excluded.ten, loai = excluded.loai, so = excluded.so,
        nam = excluded.nam, thu_tu = excluded.thu_tu, ngay_tai = now()
  returning id into v_id;

  delete from public.chi_so where ky_id = v_id;
  insert into public.chi_so (ky_id, ma_chi_tieu, gia_tri)
  select v_id, key, value::numeric from jsonb_each_text(p_chi_so);

  if p_hien then perform public.chon_ky_hien(v_id); end if;
  return v_id;
end $$;

revoke execute on function public.chon_ky_hien(uuid) from anon;
revoke execute on function public.luu_ky_bao_cao(text, text, text, int, int, int, boolean, jsonb) from anon;

-- 5. KHO ẢNH (STORAGE) -----------------------------------------------
insert into storage.buckets (id, name, public)
values ('anh-trinh-chieu', 'anh-trinh-chieu', false)
on conflict (id) do nothing;

drop policy if exists anh_xem on storage.objects;
drop policy if exists anh_them on storage.objects;
drop policy if exists anh_sua on storage.objects;
drop policy if exists anh_xoa on storage.objects;
create policy anh_xem on storage.objects for select to authenticated
  using (bucket_id = 'anh-trinh-chieu' and public.co_quyen_xem());
create policy anh_them on storage.objects for insert to authenticated
  with check (bucket_id = 'anh-trinh-chieu' and public.la_quan_tri());
create policy anh_sua on storage.objects for update to authenticated
  using (bucket_id = 'anh-trinh-chieu' and public.la_quan_tri());
create policy anh_xoa on storage.objects for delete to authenticated
  using (bucket_id = 'anh-trinh-chieu' and public.la_quan_tri());

-- 6. DỮ LIỆU BAN ĐẦU: 6 THÁNG ĐẦU NĂM 2026 ---------------------------
do $$
declare v_id uuid;
begin
  if not exists (select 1 from public.ky_bao_cao where ma = '2026-6T') then
    insert into public.ky_bao_cao (ma, ten, loai, so, nam, thu_tu, dang_hien)
    values ('2026-6T', '6 tháng đầu năm 2026', '6t', null, 2026, 6,
            not exists (select 1 from public.ky_bao_cao where dang_hien))
    returning id into v_id;

    insert into public.chi_so (ky_id, ma_chi_tieu, gia_tri)
    select v_id, key, value::numeric from jsonb_each_text('{
  "vb_llct": 16,
  "vb_tt": 12,
  "vb_bvnt": 0,
  "vb_vhvn": 4,
  "vb_dlxh": 2,
  "vb_kg": 3,
  "llct_lop": 220,
  "llct_hv": 12940,
  "llct_nt_lop": 72,
  "llct_nt_hv": 3748,
  "llct_dvm_lop": 28,
  "llct_dvm_hv": 1356,
  "llct_cm_lop": 42,
  "llct_cm_hv": 2847,
  "llct_cd_lop": 66,
  "llct_cd_hv": 3997,
  "llct_khac_lop": 12,
  "llct_khac_hv": 992,
  "nq_vb": 10,
  "nq_hn": 3,
  "nq_luot": 51000,
  "nq_diemcau": 165,
  "nq_daibieu_tt": 22000,
  "nq_hn_bu": 733,
  "nq_dv_bu": 17758,
  "nq_vb_phobien": 29,
  "nq_db_kh": 98,
  "nq_db_tong": 128,
  "tt_dinhhuong": 6,
  "tt_huongdan": 6,
  "tt_vbchidao": 22,
  "bc_vbchidao": 5,
  "bc_baocao": 6,
  "bc_giaoban": 4,
  "bc_bantin_so": 8,
  "bc_bantin_cuon": 44800,
  "dn_tinbai": 2850,
  "dn_tiepcan": 1800000,
  "dl_khaosat": 2,
  "dl_baocao": 4,
  "dl_taphuan": 8,
  "bv_goxau": 84,
  "bv_baimoi": 46,
  "bv_khaithac": 548,
  "bv_tuongtac": 10000,
  "bv_taphuan": 500,
  "kg_luotthi": 306818,
  "kg_nguoithi": 223745,
  "kg_giai_tt": 32,
  "kg_giai_cn": 48,
  "kg_dung15": 22211,
  "kg_10_14": 98998,
  "kg_5_9": 112156,
  "kg_duoi5": 73453,
  "kg_dt_vc": 63320,
  "kg_dt_cbcc": 33113,
  "kg_dt_hssv": 25954,
  "kg_dt_nd": 25508,
  "kg_dt_llvt": 15439,
  "kg_dt_ldtd": 10068,
  "kg_dt_ht": 8950,
  "kg_dt_dn": 5393
}'::jsonb);
  end if;
end $$;

insert into public.tin_noi_bat (noi_dung, thu_tu)
select * from (values
  ('Hội thi Báo cáo viên, tuyên truyền viên giỏi năm 2026: qua 03 cụm thi chọn 22 thí sinh tiêu biểu dự thi cấp tỉnh', 1),
  ('Cuộc thi trực tuyến “Tìm hiểu về Chuyển đổi số và Phong trào Bình dân học vụ số” thu hút 306.818 lượt thi', 2),
  ('Triển khai Cuộc thi chính luận về bảo vệ nền tảng tư tưởng của Đảng năm 2026', 3),
  ('Tổ chức Giải báo chí về xây dựng Đảng (Giải Búa liềm vàng) của Đảng bộ tỉnh lần thứ I, năm 2026', 4),
  ('Biên soạn, xuất bản cuốn sách “Bác Hồ với Tuyên Quang – Tuyên Quang học tập và làm theo lời Bác”', 5),
  ('6 tháng đầu năm 2026, toàn tỉnh đón trên 1,78 triệu lượt khách du lịch, doanh thu khoảng 5.003 tỷ đồng', 6),
  ('Hội nghị tuyên truyền biển, đảo tại xã Mèo Vạc thu hút 510 học sinh tham gia', 7)
) as t(noi_dung, thu_tu)
where not exists (select 1 from public.tin_noi_bat);
