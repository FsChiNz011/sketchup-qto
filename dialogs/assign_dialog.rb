# BOQ Office - Assign Category Dialog
# HtmlDialog สำหรับกำหนด Category ให้กับ Group/Component ที่เลือก

module BOQOffice
  module AssignDialog

    def self.show
      model = Sketchup.active_model
      selection = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }

      if selection.empty?
        UI.messagebox("กรุณาเลือก Group หรือ Component ก่อน\nจากนั้นคลิก Assign Category")
        return
      end

      @selection = selection
      @dialog = UI::HtmlDialog.new(
        dialog_title:    'BOQ Office - Assign Category',
        preferences_key: 'BOQOffice_Assign',
        width:           480,
        height:          560,
        min_width:       400,
        min_height:      460,
        resizable:       true
      )

      @dialog.set_html(build_html)
      @dialog.add_action_callback('assign') { |_ctx, data| do_assign(data) }
      @dialog.add_action_callback('close')  { |_ctx, _|    @dialog.close }
      @dialog.show
    end

    def self.do_assign(json_str)
      begin
        data     = JSON.parse(json_str)
        division = data['division']
        category = data['category']
        spec     = data['spec']     || ''
        desc     = data['description'] || ''

        div_info = DIVISIONS[division]
        cat_info = div_info&.dig(:categories, category)
        return unless cat_info

        unit   = cat_info[:unit]
        method = cat_info[:method]

        @selection.each do |ent|
          dict = ent.attribute_dictionary('boq_office', true)
          dict['division']    = division
          dict['category']    = category
          dict['unit']        = unit
          dict['method']      = method
          dict['spec']        = spec
          dict['description'] = desc
        end

        @dialog.close
        UI.messagebox("กำหนด Category สำเร็จ #{@selection.size} รายการ\n#{division} > #{category} (#{unit})")
      rescue => e
        UI.messagebox("เกิดข้อผิดพลาด: #{e.message}")
      end
    end

    def self.build_html
      divisions_json = DIVISIONS.map do |div_key, div_val|
        cats = div_val[:categories].map do |cat_key, cat_val|
          %Q("#{cat_key}": {"label": "#{cat_val[:label]}", "unit": "#{cat_val[:unit]}", "method": "#{cat_val[:method]}"})
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
          body { background: #f4f6f9; color: #333; padding: 16px; }
          h2 { color: #1a5276; margin-bottom: 14px; font-size: 16px; }
          .card { background: #fff; border-radius: 8px; padding: 16px; margin-bottom: 12px; box-shadow: 0 1px 4px rgba(0,0,0,.1); }
          label { display: block; font-size: 12px; color: #555; margin-bottom: 4px; font-weight: 600; }
          select, input { width: 100%; padding: 8px 10px; border: 1px solid #ccc; border-radius: 5px; font-size: 13px; background: #fafafa; }
          select:focus, input:focus { outline: none; border-color: #2980b9; background: #fff; }
          .badge { display: inline-block; background: #eaf4fb; color: #1a5276; border-radius: 12px; padding: 2px 10px; font-size: 11px; margin-top: 6px; }
          .btn { width: 100%; padding: 10px; border: none; border-radius: 6px; font-size: 14px; cursor: pointer; font-weight: 700; }
          .btn-primary { background: #2980b9; color: #fff; }
          .btn-primary:hover { background: #1a6394; }
          .btn-cancel { background: #e0e0e0; color: #555; margin-top: 6px; }
          .row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
          #unit-badge { margin-top: 8px; }
        </style>
        </head>
        <body>
          <h2>🏷️ Assign Category</h2>
          <div class="card">
            <label>หมวดงานหลัก (Division)</label>
            <select id="division" onchange="onDivChange()">
              <option value="">-- เลือกหมวดงาน --</option>
            </select>
          </div>
          <div class="card">
            <label>หมวดย่อย (Category)</label>
            <select id="category" onchange="onCatChange()">
              <option value="">-- เลือก Division ก่อน --</option>
            </select>
            <div id="unit-badge"></div>
          </div>
          <div class="card row2">
            <div>
              <label>Spec / ข้อกำหนด</label>
              <input type="text" id="spec" placeholder="เช่น 240KSC, SS400">
            </div>
            <div>
              <label>คำอธิบาย (ไม่บังคับ)</label>
              <input type="text" id="desc" placeholder="เช่น เสาชั้น 1">
            </div>
          </div>
          <button class="btn btn-primary" onclick="doAssign()">✅ บันทึก Assign</button>
          <button class="btn btn-cancel" onclick="sketchup.close()">ยกเลิก</button>

          <script>
          const DIVS = {#{divisions_json}};

          window.onload = function() {
            const sel = document.getElementById('division');
            Object.keys(DIVS).forEach(k => {
              const opt = document.createElement('option');
              opt.value = k; opt.textContent = k + ' - ' + DIVS[k].label;
              sel.appendChild(opt);
            });
          };

          function onDivChange() {
            const div = document.getElementById('division').value;
            const catSel = document.getElementById('category');
            catSel.innerHTML = '<option value="">-- เลือก Category --</option>';
            document.getElementById('unit-badge').innerHTML = '';
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
            const badge = document.getElementById('unit-badge');
            if (!div || !cat) { badge.innerHTML = ''; return; }
            const info = DIVS[div].categories[cat];
            badge.innerHTML = `<span class="badge">หน่วย: ${info.unit} &nbsp;|&nbsp; วิธีคำนวณ: ${info.method}</span>`;
          }

          function doAssign() {
            const division = document.getElementById('division').value;
            const category = document.getElementById('category').value;
            if (!division || !category) { alert('กรุณาเลือก Division และ Category'); return; }
            const payload = JSON.stringify({
              division, category,
              spec: document.getElementById('spec').value,
              description: document.getElementById('desc').value
            });
            sketchup.assign(payload);
          }
          </script>
        </body>
        </html>
      HTML
    end

  end
end
