# BOQ Office - Cost Database Dialog
# HtmlDialog สำหรับจัดการฐานข้อมูลราคาวัสดุ/ค่าแรงต่อหน่วย

module BOQOffice
  module CostDatabaseDialog

    def self.show
      @dialog&.close

      @dialog = UI::HtmlDialog.new(
        dialog_title:    'BOQ Office - ฐานข้อมูลราคา (Cost Database)',
        preferences_key: 'BOQOffice_CostDB',
        width:           780,
        height:          620,
        min_width:       640,
        min_height:      460,
        resizable:       true
      )

      @dialog.set_html(build_html)

      @dialog.add_action_callback('save')   { |_ctx, json_str| do_save(json_str) }
      @dialog.add_action_callback('delete') { |_ctx, json_str| do_delete(json_str) }
      @dialog.add_action_callback('import') { |_ctx, _|        do_import }
      @dialog.add_action_callback('close')  { |_ctx, _|        @dialog.close }

      @dialog.show
    end

    def self.do_save(json_str)
      data = JSON.parse(json_str)
      division = data['division']
      category = data['category']
      spec     = data['spec'] || ''
      material = data['material'].to_f
      labor    = data['labor'].to_f

      if division.to_s.empty? || category.to_s.empty?
        UI.messagebox('กรุณาเลือก Division และ Category')
        return
      end

      CostDatabase.set_price(division, category, spec, material, labor)
      refresh
    rescue => e
      UI.messagebox("บันทึกราคาไม่สำเร็จ: #{e.message}")
    end

    def self.do_delete(json_str)
      data = JSON.parse(json_str)
      CostDatabase.delete_price(data['division'], data['category'], data['spec'] || '')
      refresh
    rescue => e
      UI.messagebox("ลบรายการไม่สำเร็จ: #{e.message}")
    end

    def self.do_import
      path = UI.openpanel('นำเข้าราคาจาก CSV', Dir.home, 'CSV files|*.csv||')
      return unless path

      begin
        count = CostDatabase.import_csv(path)
        UI.messagebox("นำเข้าราคาสำเร็จ #{count} รายการ")
        refresh
      rescue => e
        UI.messagebox("นำเข้าไม่สำเร็จ: #{e.message}")
      end
    end

    def self.refresh
      return unless @dialog
      @dialog.execute_script("renderTable(#{entries_json});")
    end

    private

    def self.entries_json
      CostDatabase.all_entries.to_json
    end

    def self.build_html
      divisions_json = DIVISIONS.map do |div_key, div_val|
        cats = div_val[:categories].map do |cat_key, cat_val|
          %Q("#{cat_key}": {"label": "#{cat_val[:label]}", "unit": "#{cat_val[:unit]}"})
        end.join(',')
        %Q("#{div_key}": {"label": "#{div_val[:label]}", "categories": {#{cats}}})
      end.join(',')

      <<~HTML
        <!DOCTYPE html>
        <html lang="th">
        <head>
        <meta charset="UTF-8">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, sans-serif; }
          body { background: #f4f6f9; color: #2c3e50; font-size: 12px; }
          header { background: linear-gradient(135deg,#1a5276,#2980b9); color: #fff; padding: 12px 18px; display:flex; justify-content:space-between; align-items:center; }
          header h1 { font-size: 15px; }
          .layout { display: flex; gap: 0; height: calc(100vh - 46px); }
          .form-pane { width: 280px; background: #fff; border-right: 1px solid #ddd; padding: 16px; overflow-y: auto; }
          .table-pane { flex: 1; padding: 16px; overflow-y: auto; }
          label { display: block; font-size: 11px; color: #555; margin-bottom: 4px; margin-top: 10px; font-weight: 600; }
          select, input { width: 100%; padding: 7px 9px; border: 1px solid #ccc; border-radius: 5px; font-size: 12px; background: #fafafa; }
          select:focus, input:focus { outline: none; border-color: #2980b9; background: #fff; }
          .row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
          .btn { padding: 8px 14px; border: none; border-radius: 5px; font-size: 12px; cursor: pointer; font-weight: 700; }
          .btn-primary { background: #2980b9; color: #fff; width: 100%; margin-top: 14px; }
          .btn-primary:hover { background: #1a6394; }
          .btn-gray { background: #bdc3c7; color: #fff; width: 100%; margin-top: 6px; }
          .btn-import { background: #16a085; color: #fff; width: 100%; margin-top: 18px; }
          table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
          th { background: #1a5276; color: #fff; padding: 8px 10px; font-size: 11px; text-align: left; position: sticky; top: 0; }
          td { padding: 7px 10px; font-size: 12px; border-bottom: 1px solid #eee; }
          tr:hover td { background: #f0f7ff; }
          .badge { display:inline-block; border-radius:4px; padding:2px 7px; font-size:10px; font-weight:700; color:#fff; }
          .badge-arch{background:#8e44ad;} .badge-str{background:#c0392b;}
          .badge-elec{background:#d4ac0d;color:#333;} .badge-san{background:#16a085;}
          .badge-site{background:#27ae60;}
          .icon-btn { background: none; border: none; cursor: pointer; font-size: 13px; padding: 2px 4px; }
          .empty { text-align:center; color:#999; padding:30px; }
          .num { text-align: right; font-weight: 600; color: #1a5276; }
          .hint { font-size: 10px; color: #999; margin-top: 4px; }
        </style>
        </head>
        <body>
          <header>
            <h1>💰 ฐานข้อมูลราคา (Cost Database)</h1>
            <span style="font-size:11px;opacity:.8;">v1.0</span>
          </header>
          <div class="layout">
            <div class="form-pane">
              <label>หมวดงานหลัก (Division)</label>
              <select id="division" onchange="onDivChange()">
                <option value="">-- เลือกหมวดงาน --</option>
              </select>

              <label>หมวดย่อย (Category)</label>
              <select id="category" onchange="onCatChange()">
                <option value="">-- เลือก Division ก่อน --</option>
              </select>
              <div class="hint" id="unit-hint"></div>

              <label>Spec (เว้นว่าง = ราคากลางของหมวดนี้)</label>
              <input type="text" id="spec" placeholder="เช่น 240KSC, SS400">

              <div class="row2">
                <div>
                  <label>ค่าวัสดุ/หน่วย (บาท)</label>
                  <input type="number" id="material" step="0.01" value="0">
                </div>
                <div>
                  <label>ค่าแรง/หน่วย (บาท)</label>
                  <input type="number" id="labor" step="0.01" value="0">
                </div>
              </div>

              <button class="btn btn-primary" onclick="saveEntry()">💾 บันทึกราคา</button>
              <button class="btn btn-gray" onclick="clearForm()">ล้างฟอร์ม</button>
              <button class="btn btn-import" onclick="sketchup.import()">📥 นำเข้าจาก CSV</button>
              <div class="hint">CSV คอลัมน์: division,category,spec,material,labor</div>
            </div>
            <div class="table-pane">
              <table>
                <thead><tr>
                  <th>Division</th><th>Category</th><th>Spec</th>
                  <th style="text-align:right">ค่าวัสดุ</th>
                  <th style="text-align:right">ค่าแรง</th>
                  <th style="text-align:right">รวม/หน่วย</th>
                  <th style="width:60px"></th>
                </tr></thead>
                <tbody id="table-body"></tbody>
              </table>
            </div>
          </div>

          <script>
          const DIVS = {#{divisions_json}};
          const BADGE = { ARCH:'badge-arch', STR:'badge-str', ELEC:'badge-elec', SAN:'badge-san', SITE:'badge-site' };

          window.onload = function() {
            const sel = document.getElementById('division');
            Object.keys(DIVS).forEach(k => {
              const opt = document.createElement('option');
              opt.value = k; opt.textContent = k + ' - ' + DIVS[k].label;
              sel.appendChild(opt);
            });
            renderTable(#{entries_json});
          };

          function onDivChange() {
            const div = document.getElementById('division').value;
            const catSel = document.getElementById('category');
            catSel.innerHTML = '<option value="">-- เลือก Category --</option>';
            document.getElementById('unit-hint').textContent = '';
            if (!div) return;
            const cats = DIVS[div].categories;
            Object.keys(cats).forEach(k => {
              const opt = document.createElement('option');
              opt.value = k; opt.textContent = k + ' - ' + cats[k].label;
              catSel.appendChild(opt);
            });
          }

          function onCatChange() {
            const div = document.getElementById('division').value;
            const cat = document.getElementById('category').value;
            const hint = document.getElementById('unit-hint');
            if (!div || !cat) { hint.textContent = ''; return; }
            hint.textContent = 'หน่วย: ' + DIVS[div].categories[cat].unit;
          }

          function clearForm() {
            document.getElementById('division').value = '';
            document.getElementById('category').innerHTML = '<option value="">-- เลือก Division ก่อน --</option>';
            document.getElementById('spec').value = '';
            document.getElementById('material').value = 0;
            document.getElementById('labor').value = 0;
            document.getElementById('unit-hint').textContent = '';
          }

          function saveEntry() {
            const division = document.getElementById('division').value;
            const category = document.getElementById('category').value;
            if (!division || !category) { alert('กรุณาเลือก Division และ Category'); return; }
            const payload = {
              division, category,
              spec: document.getElementById('spec').value.trim(),
              material: parseFloat(document.getElementById('material').value) || 0,
              labor: parseFloat(document.getElementById('labor').value) || 0
            };
            sketchup.save(JSON.stringify(payload));
          }

          function deleteEntry(division, category, spec) {
            if (!confirm('ลบราคานี้ใช่หรือไม่?')) return;
            sketchup.delete(JSON.stringify({ division, category, spec }));
          }

          function editEntry(division, category, spec, material, labor) {
            document.getElementById('division').value = division;
            onDivChange();
            document.getElementById('category').value = category;
            onCatChange();
            document.getElementById('spec').value = spec;
            document.getElementById('material').value = material;
            document.getElementById('labor').value = labor;
          }

          function escAttr(str) {
            return String(str).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
          }

          function renderTable(entries) {
            const tbody = document.getElementById('table-body');
            if (!entries || entries.length === 0) {
              tbody.innerHTML = '<tr><td colspan="7" class="empty">ยังไม่มีข้อมูลราคา — กรอกฟอร์มด้านซ้ายเพื่อเริ่มต้น</td></tr>';
              return;
            }
            tbody.innerHTML = entries.map(e => {
              const total = (e.material + e.labor).toFixed(2);
              const badge = BADGE[e.division] || '';
              const specLabel = e.spec && e.spec.length ? escapeHtml(e.spec) : '<span style="color:#aaa">(ราคากลาง)</span>';
              const div = escAttr(e.division), cat = escAttr(e.category), spec = escAttr(e.spec || '');
              return `<tr>
                <td><span class="badge ${badge}">${e.division}</span></td>
                <td>${escapeHtml(e.category)}</td>
                <td>${specLabel}</td>
                <td class="num">${e.material.toFixed(2)}</td>
                <td class="num">${e.labor.toFixed(2)}</td>
                <td class="num">${total}</td>
                <td>
                  <button class="icon-btn" title="แก้ไข" onclick="editEntry('${div}','${cat}','${spec}',${e.material},${e.labor})">✏️</button>
                  <button class="icon-btn" title="ลบ" onclick="deleteEntry('${div}','${cat}','${spec}')">🗑️</button>
                </td>
              </tr>`;
            }).join('');
          }

          function escapeHtml(str) {
            const div = document.createElement('div');
            div.textContent = String(str);
            return div.innerHTML;
          }
          </script>
        </body>
        </html>
      HTML
    end

  end
end
