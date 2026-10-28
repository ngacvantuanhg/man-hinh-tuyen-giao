-- =====================================================================
-- MÀN HÌNH THEO DÕI CÔNG TÁC TUYÊN GIÁO - CẬP NHẬT BƯỚC 5
-- Chạy trong project của MÀN HÌNH (tgdv-miniapp) > SQL Editor.
-- Chạy lại nhiều lần vẫn an toàn. Dữ liệu cũ giữ nguyên.
--   1. Cho phép kỳ lũy kế "10 tháng", "11 tháng"
--   2. Bảng điểm trên bản đồ dư luận xã hội (do cán bộ xác nhận)
-- =====================================================================

-- 1. KỲ LŨY KẾ ---------------------------------------------------------
alter table public.ky_bao_cao drop constraint if exists ky_bao_cao_loai_check;
alter table public.ky_bao_cao add constraint ky_bao_cao_loai_check
  check (loai in ('thang', 'quy', '6t', '9t', 'lk', 'nam'));

-- 2. BẢNG ĐIỂM BẢN ĐỒ ----------------------------------------------------
create table if not exists public.mh_diem_ban_do (
  id        bigint generated always as identity primary key,
  ten_xa    text not null,                       -- vd: Xã Lũng Cú
  lat       numeric not null,
  lon       numeric not null,
  sac_thai  text not null check (sac_thai in ('tich_cuc', 'tieu_cuc')),
  muc_do    text check (muc_do in ('theo_doi', 'can_xu_ly')),  -- chỉ dùng cho tiêu cực
  tieu_de   text not null,
  tom_tat   text,
  nguon     text,
  link      text,
  ngay      date not null default current_date,
  hien_den  date not null default (current_date + 7),       -- hết ngày này thì tự ẩn
  hien      boolean not null default true,
  ngay_tao  timestamptz not null default now()
);
create index if not exists mh_diem_ban_do_hien_den on public.mh_diem_ban_do (hien_den);

alter table public.mh_diem_ban_do enable row level security;
drop policy if exists mh_diem_ban_do_xem on public.mh_diem_ban_do;
drop policy if exists mh_diem_ban_do_them on public.mh_diem_ban_do;
drop policy if exists mh_diem_ban_do_sua on public.mh_diem_ban_do;
drop policy if exists mh_diem_ban_do_xoa on public.mh_diem_ban_do;
create policy mh_diem_ban_do_xem on public.mh_diem_ban_do for select to authenticated
  using (public.co_quyen_xem());
create policy mh_diem_ban_do_them on public.mh_diem_ban_do for insert to authenticated
  with check (public.la_quan_tri());
create policy mh_diem_ban_do_sua on public.mh_diem_ban_do for update to authenticated
  using (public.la_quan_tri()) with check (public.la_quan_tri());
create policy mh_diem_ban_do_xoa on public.mh_diem_ban_do for delete to authenticated
  using (public.la_quan_tri());

-- 3. BẢO ĐẢM TÀI KHOẢN ĐĂNG NHẬP GỌI ĐƯỢC CÁC HÀM KIỂM TRA QUYỀN --------
grant execute on function public.vai_tro_hien_tai() to authenticated;
grant execute on function public.la_quan_tri() to authenticated;
grant execute on function public.co_quyen_xem() to authenticated;

-- Kiểm tra: phải thấy dòng 'lk' trong ràng buộc và bảng mh_diem_ban_do
select pg_get_constraintdef(oid) as rang_buoc_loai_ky
from pg_constraint where conname = 'ky_bao_cao_loai_check';
select count(*) as so_diem_ban_do from public.mh_diem_ban_do;
