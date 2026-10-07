-- =====================================================================
-- BƯỚC 2: CẤP QUYỀN CHO 2 TÀI KHOẢN
-- Làm sau khi đã tạo 2 tài khoản trong Authentication > Users.
-- Thay 2 địa chỉ email bên dưới bằng email thật rồi chạy trong SQL Editor.
-- =====================================================================

-- Tài khoản quản trị (người tải số liệu, ảnh, tin)
insert into public.quyen (user_id, vai_tro, ghi_chu)
select id, 'quan_tri', 'Quản trị' from auth.users
where email = 'tuan.quantri@gmail.com'
on conflict (user_id) do update set vai_tro = excluded.vai_tro;

-- Tài khoản máy TV (chỉ xem)
insert into public.quyen (user_id, vai_tro, ghi_chu)
select id, 'xem', 'Máy TV phòng họp' from auth.users
where email = 'ngacvantuan.hg@gmail.com'
on conflict (user_id) do update set vai_tro = excluded.vai_tro;

-- Kiểm tra: phải thấy đủ 2 dòng
select u.email, q.vai_tro, q.ghi_chu
from public.quyen q join auth.users u on u.id = q.user_id;
