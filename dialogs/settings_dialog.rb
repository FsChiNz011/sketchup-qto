# BOQ Office - Project Settings Dialog
# กรอกข้อมูลโครงการ (ชื่อ, สถานที่, หน่วยงาน, ผู้คำนวณ, คณะกรรมการ)

module BOQOffice
  module SettingsDialog

    def self.show
      @dialog&.close

      @dialog = UI::HtmlDialog.new(
        dialog_title:    'BOQ Office - ตั้งค่าโครงการ',
        preferences_key: 'BOQOffice_Settings',
        width:           560,
        height:          640,
        min_width:       480,
        min_height:      460,
        resizable:       true
      )

      @dialog.set_html(build_html)
      @dialog.add_action_callback('save')  { |_ctx, json_str| do_save(json_str) }
      @dialog.add_action_callback('close') { |_ctx, _| @dialog.close }
      @dialog.show
    end

    def self.do_save(json_str)
      data = JSON.parse(json_str)
      ProjectSettings.update(data)
      UI.messagebox('บันทึกการตั้งค่าโครงการสำเร็จ')
      @dialog.close
    rescue => e
      UI.messagebox("บันทึกไม่สำเร็จ: #{e.message}")
    end

    def self.build_html
      s = ProjectSettings.data
      committee = (s['committee'] || [])
      committee_rows = committee.map.with_index do |m, i|
        "{name: #{(m['name'] || '').to_json}, position: #{(m['position'] || '').to_json}}"
      end.join(',')

      <<~HTML
        <!DOCTYPE html>
        <html lang="th">
        <head>
        <meta charset="UTF-8">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, sans-serif; }
          body { background: #f4f6f9; color: #2c3e50; font-size: 12px; }
          header { background: linear-gradient(135deg,#1a5276,#2980b9); color: #fff; padding: 12px 18px; }
          header h1 { font-size: 15px; }
          .content { padding: 16px; }
          label { display: block; font-size: 11px; color: #555; margin-bottom: 4px; margin-top: 12px; font-weight: 600; }
          input, textarea { width: 100%; padding: 7px 9px; border: 1px solid #ccc; border-radius: 5px; font-size: 12px; background: #fafafa; }
          input:focus, textarea:focus { outline: none; border-color: #2980b9; background: #fff; }
          textarea { min-height: 50px; resize: vertical; }
          .committee-row { display: grid; grid-template-columns: 1fr 1fr auto; gap: 6px; margin-top: 6px; align-items: center; }
          .btn { padding: 9px 16px; border: none; border-radius: 5px; font-size: 12px; cursor: pointer; font-weight: 700; }
          .btn-primary { background: #2980b9; color: #fff; width: 100%; margin-top: 18px; }
          .btn-primary:hover { background: #1a6394; }
          .btn-add { background: #16a085; color: #fff; padding: 6px 12px; margin-top: 8px; }
          .btn-del { background: #e74c3c; color: #fff; padding: 6px 10px; font-size: 11px; }
          .section-title { font-size: 13px; font-weight: 700; color: #1a5276; margin-top: 18px; border-bottom: 2px solid #eaf4fb; padding-bottom: 4px; }
        </style>
        </head>
        <body>
          <header><h1>⚙️ ตั้งค่าโครงการ</h1></header>
          <div class="content">
            <label>ชื่อโครงการ</label>
            <input type="text" id="project_name" value="#{escape_html(s['project_name'])}">

            <label>สถานที่ก่อสร้าง</label>
            <input type="text" id="location" value="#{escape_html(s['location'])}">

            <label>หน่วยงานเจ้าของโครงการ</label>
            <input type="text" id="owner_org" value="#{escape_html(s['owner_org'])}">

            <label>แบบเลขที่</label>
            <input type="text" id="drawing_no" value="#{escape_html(s['drawing_no'])}">

            <label>คำนวณราคากลางโดย</label>
            <input type="text" id="calculated_by" value="#{escape_html(s['calculated_by'])}">

            <label>อ้างอิงราคาวัสดุ (แสดงในหมายเหตุ ปร.4)</label>
            <textarea id="price_ref">#{escape_html(s['price_ref'])}</textarea>

            <div class="section-title">คณะกรรมการกำหนดราคากลาง</div>
            <div id="committee-list"></div>
            <button class="btn btn-add" onclick="addMember()">+ เพิ่มกรรมการ</button>

            <button class="btn btn-primary" onclick="saveSettings()">💾 บันทึกการตั้งค่า</button>
          </div>

          <script>
            let committee = [#{committee_rows}];

            function renderCommittee() {
              const list = document.getElementById('committee-list');
              list.innerHTML = committee.map((m, i) => `
                <div class="committee-row">
                  <input type="text" placeholder="ชื่อ-สกุล" value="${escapeAttr(m.name)}" onchange="updateMember(${i},'name',this.value)">
                  <input type="text" placeholder="ตำแหน่ง" value="${escapeAttr(m.position)}" onchange="updateMember(${i},'position',this.value)">
                  <button class="btn btn-del" onclick="removeMember(${i})">ลบ</button>
                </div>
              `).join('');
            }

            function escapeAttr(str) {
              const div = document.createElement('div');
              div.textContent = String(str || '');
              return div.innerHTML;
            }

            function addMember() {
              committee.push({ name: '', position: '' });
              renderCommittee();
            }

            function removeMember(i) {
              committee.splice(i, 1);
              renderCommittee();
            }

            function updateMember(i, field, value) {
              committee[i][field] = value;
            }

            function saveSettings() {
              const payload = {
                project_name:  document.getElementById('project_name').value.trim(),
                location:      document.getElementById('location').value.trim(),
                owner_org:     document.getElementById('owner_org').value.trim(),
                drawing_no:    document.getElementById('drawing_no').value.trim(),
                calculated_by: document.getElementById('calculated_by').value.trim(),
                price_ref:     document.getElementById('price_ref').value.trim(),
                committee:     committee.filter(m => m.name.trim() || m.position.trim())
              };
              sketchup.save(JSON.stringify(payload));
            }

            renderCommittee();
          </script>
        </body>
        </html>
      HTML
    end

    def self.escape_html(str)
      (str || '').to_s
        .gsub('&', '&amp;')
        .gsub('<', '&lt;')
        .gsub('>', '&gt;')
        .gsub('"', '&quot;')
    end

  end
end
