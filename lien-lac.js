/* Hộp "Liên hệ" khi bấm vào một điểm dư luận.
   Dùng chung cho màn hình theo dõi (index.html) và trang quản trị (quan-tri.html).
   Hiện thông tin vụ việc, đầu mối của xã (bảng mh_dau_moi_xa) và các nút:
   mở phòng họp Google Meet, nhắn Zalo, gọi điện, sao chép lời mời họp để gửi cho xã. */
(function () {
  const CH = window.CAU_HINH_LIEN_LAC || {};
  const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const linkAnToan = u => /^https?:\/\//i.test(String(u || "").trim()) ? String(u).trim() : "";
  const soDT = s => String(s || "").replace(/[^\d+]/g, "");
  const MAU = { tich_cuc: "#34C38F", theo_doi: "#F59F3A", can_xu_ly: "#E0243F" };
  const TEN = { tich_cuc: "Tích cực", theo_doi: "Theo dõi", can_xu_ly: "Cần xử lý" };
  const loai = d => d.sac_thai === "tich_cuc" ? "tich_cuc" : (d.muc_do === "can_xu_ly" ? "can_xu_ly" : "theo_doi");
  const laTinh = d => /^toàn tỉnh$/i.test(String(d.ten_xa || "").trim());
  const ngayVN = s => { const p = String(s || "").split("-"); return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : ""; };

  const css = `
  .ll-nen { position: fixed; inset: 0; z-index: 9999; background: rgba(4,9,18,.62); display: grid; place-items: center; padding: 16px; }
  .ll-hop { width: min(580px, 100%); max-height: calc(100vh - 32px); overflow: auto; background: #0F1D33; color: #E8EEF6;
    border-radius: 16px; border-top: 5px solid var(--ll-mau); box-shadow: 0 24px 60px rgba(0,0,0,.5);
    font-family: "Be Vietnam Pro", "Segoe UI", Arial, sans-serif; font-size: 15px; line-height: 1.5; }
  .ll-dau { display: flex; align-items: center; gap: 10px; padding: 16px 18px 0; }
  .ll-the { font-size: 12px; font-weight: 700; padding: 2px 10px; border-radius: 999px; background: var(--ll-mau); color: #081326; }
  .ll-noi { color: #9FB0C7; font-size: 13.5px; flex: 1; }
  .ll-dong { background: none; border: 0; color: #9FB0C7; font-size: 26px; line-height: 1; cursor: pointer; padding: 2px 6px; border-radius: 8px; }
  .ll-dong:hover { color: #fff; background: rgba(255,255,255,.08); }
  .ll-than { padding: 8px 18px 18px; display: grid; gap: 12px; }
  .ll-than h2 { margin: 0; font-size: 19px; line-height: 1.35; color: #fff; }
  .ll-than p { margin: 0; color: #C5D0DE; }
  .ll-than a.ll-bai { color: #8DB8F5; }
  .ll-dm { background: rgba(255,255,255,.05); border-radius: 12px; padding: 12px 14px; display: grid; gap: 2px; }
  .ll-dm .nhan { font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: #9FB0C7; font-weight: 700; }
  .ll-dm b { font-size: 16px; color: #fff; }
  .ll-dm .sdt { font-size: 22px; font-weight: 700; color: #F5E236; letter-spacing: .5px; user-select: all; }
  .ll-dm .trong { color: #FFC27A; font-size: 14px; }
  .ll-nut { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .ll-nut a, .ll-nut button { display: flex; align-items: center; justify-content: center; gap: 8px; min-height: 46px; padding: 8px 12px;
    border-radius: 10px; font: inherit; font-weight: 700; text-decoration: none; cursor: pointer; border: 1px solid rgba(255,255,255,.14);
    background: rgba(255,255,255,.06); color: #fff; }
  .ll-nut a:hover, .ll-nut button:hover { background: rgba(255,255,255,.12); }
  .ll-nut .meet { grid-column: 1 / -1; background: #C8102E; border-color: #C8102E; font-size: 16px; min-height: 52px; }
  .ll-nut .meet:hover { background: #A50D26; }
  .ll-nut .zalo { background: #0068FF; border-color: #0068FF; }
  .ll-nut .zalo:hover { background: #0052CC; }
  .ll-nut [aria-disabled="true"] { opacity: .4; pointer-events: none; }
  .ll-nut a:focus-visible, .ll-nut button:focus-visible, .ll-dong:focus-visible { outline: 3px solid #F5A623; outline-offset: 2px; }
  .ll-luu { font-size: 12.5px; color: #8A9BB4; }
  .ll-bao { font-size: 13.5px; color: #7FE0B8; min-height: 1.2em; }
  .ll-sao { width: 100%; min-height: 84px; font: inherit; font-size: 13px; border-radius: 8px; padding: 8px; background: #081326; color: #DCE6F2; border: 1px solid rgba(255,255,255,.15); }
  `;
  const st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);

  let nen = null, dsKhiDong = [];
  function dong() {
    if (!nen) return;
    nen.remove(); nen = null;
    document.removeEventListener("keydown", phimEsc);
    const fs = dsKhiDong; dsKhiDong = []; fs.forEach(f => { try { f(); } catch (e) {} });
  }
  function phimEsc(e) { if (e.key === "Escape") dong(); }

  async function mo(d, sb) {
    dong();
    const l = loai(d), tinh = laTinh(d);
    nen = document.createElement("div");
    nen.className = "ll-nen";
    nen.innerHTML = `<div class="ll-hop" role="dialog" aria-modal="true" aria-label="Liên hệ về vụ việc" style="--ll-mau:${MAU[l]}">
      <div class="ll-dau"><span class="ll-the">${TEN[l]}</span><span class="ll-noi">${esc(d.ten_xa)}${d.ngay ? " · " + ngayVN(d.ngay) : ""}${d.nguon ? " · " + esc(d.nguon) : ""}</span>
        <button class="ll-dong" aria-label="Đóng">×</button></div>
      <div class="ll-than">
        <h2>${esc(d.tieu_de)}</h2>
        ${d.tom_tat ? `<p>${esc(d.tom_tat)}</p>` : ""}
        ${linkAnToan(d.link) ? `<p><a class="ll-bai" href="${esc(linkAnToan(d.link))}" target="_blank" rel="noopener">Xem bài viết gốc ↗</a></p>` : ""}
        <div class="ll-dm" id="llDauMoi"><span class="nhan">Đầu mối ${tinh ? "" : "của xã"}</span><span class="ll-luu">Đang tải danh bạ…</span></div>
        <div class="ll-nut" id="llNut"></div>
        <div class="ll-bao" id="llBao" aria-live="polite"></div>
        <div class="ll-luu">Không trao đổi nội dung thuộc bí mật nhà nước qua Zalo, Google Meet.</div>
      </div></div>`;
    document.body.appendChild(nen);
    nen.addEventListener("click", e => { if (e.target === nen || e.target.closest(".ll-dong")) dong(); });
    document.addEventListener("keydown", phimEsc);
    nen.querySelector(".ll-dong").focus();

    // Đầu mối của xã
    let dm = null, loiDanhBa = "";
    if (!tinh && sb) {
      try {
        const { data, error } = await sb.from("mh_dau_moi_xa").select("*").eq("ten_xa", d.ten_xa).maybeSingle();
        if (error) throw error;
        dm = data;
      } catch (e) { loiDanhBa = "Chưa đọc được danh bạ đầu mối (đã chạy file buoc7_danh_ba_dau_moi.sql chưa?)."; }
    }
    if (!nen) return;   // người dùng đã đóng trong lúc chờ
    const sdt = soDT(dm && dm.dien_thoai);
    const phong = linkAnToan(dm && dm.phong_hop) || linkAnToan(CH.phongHop);
    nen.querySelector("#llDauMoi").innerHTML = tinh
      ? `<span class="nhan">Đầu mối</span><span class="ll-luu">Vụ việc chung của tỉnh: mời các đơn vị liên quan vào phòng họp trực tuyến.</span>`
      : dm && (dm.ho_ten || sdt)
        ? `<span class="nhan">Đầu mối của xã</span><b>${esc(dm.ho_ten || "")}</b>${dm.chuc_vu ? `<span>${esc(dm.chuc_vu)}</span>` : ""}${sdt ? `<span class="sdt">${esc(dm.dien_thoai)}</span>` : ""}`
        : `<span class="nhan">Đầu mối của xã</span><span class="trong">${esc(loiDanhBa || "Xã này chưa có trong danh bạ. Nhập ở trang quản trị, tab “Danh bạ đầu mối”.")}</span>`;

    nen.querySelector("#llNut").innerHTML = `
      <a class="meet" ${phong ? `href="${esc(phong)}" target="_blank" rel="noopener"` : `aria-disabled="true"`}>▶ Mở phòng họp Google Meet</a>
      <a class="zalo" ${sdt ? `href="https://zalo.me/${esc(sdt.replace(/^\+?84/, "0"))}" target="_blank" rel="noopener"` : `aria-disabled="true"`}>Nhắn Zalo</a>
      <a ${sdt ? `href="tel:${esc(sdt)}"` : `aria-disabled="true"`}>Gọi điện</a>
      <button type="button" id="llSaoChep" style="grid-column:1/-1">Sao chép lời mời họp (dán vào Zalo)</button>`;

    const loiMoi = `Kính gửi ${dm && dm.ho_ten ? "đồng chí " + dm.ho_ten : "đồng chí"}${dm && dm.chuc_vu ? " (" + dm.chuc_vu + ")" : ""}${tinh ? "" : ", " + d.ten_xa}.
${CH.tenCoQuan || "Ban Tuyên giáo Tỉnh ủy"} đề nghị đồng chí vào họp trực tuyến để trao đổi về: ${d.tieu_de}.
Đường dẫn phòng họp: ${phong}`;
    nen.querySelector("#llSaoChep").addEventListener("click", async () => {
      const bao = nen.querySelector("#llBao");
      try { await navigator.clipboard.writeText(loiMoi); bao.textContent = "Đã sao chép lời mời. Mở Zalo và dán (Ctrl+V) để gửi cho xã."; }
      catch (e) {
        bao.innerHTML = `Máy không cho sao chép tự động. Bôi đen đoạn dưới rồi bấm Ctrl+C:<textarea class="ll-sao" readonly>${esc(loiMoi)}</textarea>`;
        const ta = bao.querySelector("textarea"); ta.focus(); ta.select();
      }
    });
  }

  window.LienLac = { mo, dong, dangMo: () => !!nen, khiDong: f => { if (nen) dsKhiDong.push(f); else f(); } };
})();
