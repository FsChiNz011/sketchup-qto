# BOQ Office - Dashboard Dialog v1.0.0
# v0.2.1: แสดง BOQ Table ใน Generate BOQ + แสดงปริมาณแยกรายชิ้น
# v0.9.0: เพิ่มยอดรวมมูลค่า (จาก Cost Database) + ปุ่ม Cost Database + แจ้งเตือนรายการที่ยังไม่มีราคา
# v1.0.0: เพิ่มปุ่ม Settings/ปร.1/ปร.4(ราคากลาง) + ใช้ ProjectSettings เป็นแหล่งชื่อโครงการเดียวกันทั้งระบบ

module BOQOffice
  module Dashboard

    def self.show(scan_results = nil)
      @dialog&.close

      @dialog = UI::HtmlDialog.new(
        dialog_title:    'BOQ Office - Dashboard',
        preferences_key: 'BOQOffice_Dashboard',
        width:           860,
        height:          660,
        min_width:       700,
        min_height:      500,
        resizable:       true
      )

      results = scan_results || Scanner.last_results
      boq     = results.empty? ? nil : BOQGenerator.build_boq(results)

      @dialog.set_html(build_html(results, boq))

      @dialog.add_action_callback('scan')      { |_ctx, _| @dialog.close; Scanner.scan_model }
      @dialog.add_action_callback('assign')    { |_ctx, _| AssignDialog.show }
      @dialog.add_action_callback('generate')  { |_ctx, _| show_boq_table }
      @dialog.add_action_callback('costdb')    { |_ctx, _| CostDatabaseDialog.show }
      @dialog.add_action_callback('settings')  { |_ctx, _| SettingsDialog.show }
      @dialog.add_action_callback('csv')       { |_ctx, _| Exporter.export_csv }
      @dialog.add_action_callback('excel')     { |_ctx, _| Exporter.export_excel }
      @dialog.add_action_callback('pr1')       { |_ctx, _| Exporter.export_pr1 }
      @dialog.add_action_callback('pr4')       { |_ctx, _| Exporter.export_pr4 }
      @dialog.add_action_callback('pr4final')  { |_ctx, _| Exporter.export_pr4_final }
      @dialog.add_action_callback('pr5')       { |_ctx, _| Exporter.export_pr5 }
      @dialog.add_action_callback('close')     { |_ctx, _| @dialog.close }

      @dialog.show
    end

    # เรียกเมื่อกด Generate BOQ — เปิด dialog ใหม่แสดงตาราง
    def self.show_boq_table
      results = Scanner.last_results
      if results.nil? || results.empty?
        answer = UI.messagebox('ยังไม่มีข้อมูล Scan\nต้องการ Scan Model ก่อนหรือไม่?', MB_YESNO)
        if answer == IDYES
          results = Scanner.scan_model
          return if results.nil? || results.empty?
        else
          return
        end
      end

      boq  = BOQGenerator.build_boq(results)
      rows = BOQGenerator.to_flat_array(boq)
      BOQGenerator.instance_variable_set(:@last_boq, boq)

      @boq_dialog&.close
      @boq_dialog = UI::HtmlDialog.new(
        dialog_title:    'BOQ Office - ตาราง BOQ',
        preferences_key: 'BOQOffice_BOQTable',
        width:           960,
        height:          680,
        min_width:       800,
        min_height:      500,
        resizable:       true
      )
      @boq_dialog.set_html(build_boq_html(results, rows))
      @boq_dialog.add_action_callback('costdb')   { |_ctx, _| CostDatabaseDialog.show }
      @boq_dialog.add_action_callback('excel')    { |_ctx, _| Exporter.export_excel }
      @boq_dialog.add_action_callback('pr1')      { |_ctx, _| Exporter.export_pr1 }
      @boq_dialog.add_action_callback('pr4')      { |_ctx, _| Exporter.export_pr4 }
      @boq_dialog.add_action_callback('pr4final') { |_ctx, _| Exporter.export_pr4_final }
      @boq_dialog.add_action_callback('pr5')      { |_ctx, _| Exporter.export_pr5 }
      @boq_dialog.add_action_callback('csv')      { |_ctx, _| Exporter.export_csv }
      @boq_dialog.add_action_callback('close')    { |_ctx, _| @boq_dialog.close }
      @boq_dialog.show
    end

    def self.show_boq(boq)
      show(Scanner.last_results)
    end

    def self.show_about
      UI.messagebox(
        "BOQ Office v#{BOQOffice::EXTENSION_VERSION}\n" \
        "ระบบถอดปริมาณและประมาณราคางานก่อสร้าง\n\n" \
        "พัฒนาโดย: ส่วนควบคุมการก่อสร้าง\n" \
        "รองรับ: SketchUp 2023+\n\n" \
        "รองรับการจัดทำ BOQ, ปร.4 และ ปร.5\n" \
        "สำหรับหน่วยงานภาครัฐและองค์กรปกครองส่วนท้องถิ่น"
      )
    end

    private

    # ==============================
    # HTML: หน้า Dashboard หลัก
    # ==============================
    def self.build_html(results, boq)
      item_count    = results.size
      division_rows = build_division_summary(results)
      project_name  = ProjectSettings.project_name

      flat_rows         = results.empty? ? [] : BOQGenerator.to_flat_array(boq)
      grand_total_value = BOQGenerator.grand_total(flat_rows)
      missing_count     = BOQGenerator.missing_price_count(flat_rows)

      table_html = if results.empty?
        '<tr><td colspan="4" style="text-align:center;color:#999;padding:24px;">ยังไม่มีข้อมูล — กด Scan Model เพื่อเริ่มต้น</td></tr>'
      else
        division_rows.map do |row|
          "<tr>
            <td><span class='badge badge-#{row[:div].downcase}'>#{row[:div]}</span></td>
            <td>#{row[:label]}</td>
            <td style='text-align:right;'>#{row[:count]}</td>
            <td style='text-align:right;'>#{row[:categories]}</td>
          </tr>"
        end.join
      end

      <<~HTML
        <!DOCTYPE html><html lang="th"><head><meta charset="UTF-8">
        <style>
          *{box-sizing:border-box;margin:0;padding:0;font-family:'Segoe UI',Tahoma,sans-serif;}
          body{background:#ecf0f1;color:#2c3e50;}
          header{background:linear-gradient(135deg,#1a5276,#2980b9);color:#fff;padding:14px 20px;display:flex;align-items:center;justify-content:space-between;}
          header h1{font-size:18px;}
          .ver{font-size:11px;opacity:.7;}
          .project-bar{background:#d5e8f3;padding:6px 20px;font-size:12px;color:#1a5276;}
          .toolbar{display:flex;gap:8px;padding:12px 20px;background:#fff;border-bottom:1px solid #ddd;flex-wrap:wrap;}
          .btn{padding:7px 14px;border:none;border-radius:5px;font-size:12px;cursor:pointer;font-weight:600;transition:background .2s;}
          .btn-blue{background:#2980b9;color:#fff;} .btn-blue:hover{background:#1a6394;}
          .btn-green{background:#27ae60;color:#fff;} .btn-green:hover{background:#1e8449;}
          .btn-orange{background:#e67e22;color:#fff;} .btn-orange:hover{background:#ca6f1e;}
          .btn-gray{background:#bdc3c7;color:#fff;} .btn-gray:hover{background:#a0a6aa;}
          .btn-teal{background:#16a085;color:#fff;} .btn-teal:hover{background:#0d8069;}
          .btn-purple{background:#8e44ad;color:#fff;} .btn-purple:hover{background:#703688;}
          .content{padding:16px 20px;}
          .stat-row{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin-bottom:16px;}
          .stat{background:#fff;border-radius:8px;padding:12px;text-align:center;box-shadow:0 1px 4px rgba(0,0,0,.08);}
          .stat .num{font-size:24px;font-weight:700;color:#2980b9;}
          .stat .lbl{font-size:10px;color:#888;margin-top:2px;}
          .stat.money .num{font-size:18px;color:#16a085;}
          .stat.warn .num{color:#e67e22;}
          table{width:100%;border-collapse:collapse;background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08);}
          th{background:#1a5276;color:#fff;padding:10px 12px;font-size:12px;text-align:left;}
          td{padding:9px 12px;font-size:12px;border-bottom:1px solid #eee;}
          tr:last-child td{border-bottom:none;}
          tr:hover td{background:#f0f7ff;}
          .badge{display:inline-block;border-radius:4px;padding:2px 8px;font-size:11px;font-weight:700;color:#fff;}
          .badge-arch{background:#8e44ad;} .badge-str{background:#c0392b;}
          .badge-elec{background:#d4ac0d;color:#333;} .badge-san{background:#16a085;}
          .badge-site{background:#27ae60;}
          footer{padding:8px 20px;font-size:10px;color:#aaa;text-align:right;}
        </style></head><body>
          <header>
            <div><h1>📊 BOQ Office</h1><div class="ver">ระบบถอดปริมาณและประมาณราคางานก่อสร้าง</div></div>
            <div class="ver">v#{BOQOffice::EXTENSION_VERSION}</div>
          </header>
          <div class="project-bar">🏗️ โครงการ: #{project_name}</div>
          <div class="toolbar">
            <button class="btn btn-blue"   onclick="sketchup.assign()">🏷️ Assign Category</button>
            <button class="btn btn-blue"   onclick="sketchup.scan()">🔍 Scan Model</button>
            <button class="btn btn-green"  onclick="sketchup.generate()">📋 Generate BOQ</button>
            <button class="btn btn-purple" onclick="sketchup.costdb()">💰 Cost Database</button>
            <button class="btn btn-purple" onclick="sketchup.settings()">⚙️ ตั้งค่าโครงการ</button>
            <button class="btn btn-orange" onclick="sketchup.excel()">📊 Export Excel</button>
            <button class="btn btn-teal"   onclick="sketchup.pr1()">📄 ปร.1</button>
            <button class="btn btn-teal"   onclick="sketchup.pr4()">📄 ปร.4</button>
            <button class="btn btn-teal"   onclick="sketchup.pr4final()">📄 ปร.4(ราคากลาง)</button>
            <button class="btn btn-teal"   onclick="sketchup.pr5()">📄 ปร.5</button>
            <button class="btn btn-gray"   onclick="sketchup.csv()">📁 CSV</button>
          </div>
          <div class="content">
            <div class="stat-row">
              <div class="stat"><div class="num">#{item_count}</div><div class="lbl">รายการทั้งหมด</div></div>
              <div class="stat"><div class="num" style="color:#8e44ad">#{count_div(results,'ARCH')}</div><div class="lbl">ARCH</div></div>
              <div class="stat"><div class="num" style="color:#c0392b">#{count_div(results,'STR')}</div><div class="lbl">STR</div></div>
              <div class="stat"><div class="num" style="color:#d4ac0d">#{count_div(results,'ELEC')}</div><div class="lbl">ELEC</div></div>
              <div class="stat"><div class="num" style="color:#16a085">#{count_div(results,'SAN')}</div><div class="lbl">SAN</div></div>
              <div class="stat money"><div class="num">#{format_money(grand_total_value)}</div><div class="lbl">มูลค่ารวม (บาท)</div></div>
            </div>
            #{missing_price_warning(flat_rows)}
            <table>
              <thead><tr>
                <th>Division</th><th>ชื่อหมวดงาน</th>
                <th style="text-align:right">จำนวนรายการ</th>
                <th style="text-align:right">จำนวน Category</th>
              </tr></thead>
              <tbody>#{table_html}</tbody>
            </table>
          </div>
          <footer>BOQ Office — ส่วนควบคุมการก่อสร้าง | #{Time.now.strftime('%d/%m/%Y %H:%M')}</footer>
        </body></html>
      HTML
    end

    # ==============================
    # HTML: หน้า BOQ Table (Generate BOQ)
    # ==============================
    def self.build_boq_html(results, rows)
      project_name = ProjectSettings.project_name

      tbody = rows.map do |row|
        if row[:type] == 'division_header'
          div_key = row[:division]
          color = { 'ARCH' => '#8e44ad','STR' => '#c0392b','ELEC' => '#b7950b',
                    'SAN'  => '#16a085','SITE' => '#27ae60' }[div_key] || '#555'
          "<tr class='div-header'>
            <td colspan='7' style='background:#{color};color:#fff;font-weight:700;padding:8px 12px;'>
              #{row[:label]}
            </td>
          </tr>"
        else
          qty_fmt   = row[:quantity] == row[:quantity].to_i ? row[:quantity].to_i : ('%.3f' % row[:quantity])
          price_fmt = row[:has_price] ? format_money(row[:unit_price]) : '<span style="color:#e67e22;">ยังไม่มีราคา</span>'
          total_fmt = row[:has_price] ? format_money(row[:total]) : '—'
          "<tr>
            <td style='text-align:center;color:#888;'>#{row[:item_no]}</td>
            <td>#{row[:description]}</td>
            <td style='color:#666;font-size:11px;'>#{row[:spec]}</td>
            <td style='text-align:center;'>#{row[:unit]}</td>
            <td style='text-align:right;font-weight:600;color:#1a5276;'>#{qty_fmt}</td>
            <td style='text-align:right;font-size:11px;'>#{price_fmt}</td>
            <td style='text-align:right;font-weight:600;color:#16a085;'>#{total_fmt}</td>
          </tr>"
        end
      end.join

      grand_total = BOQGenerator.grand_total(rows)

      # สรุปปริมาณแยกรายชิ้น (detail items)
      detail_rows = results.map.with_index(1) do |item, i|
        qty_fmt = item[:quantity] == item[:quantity].to_i ? item[:quantity].to_i : ('%.3f' % item[:quantity])
        div_color = { 'ARCH' => '#8e44ad','STR' => '#c0392b','ELEC' => '#b7950b',
                      'SAN'  => '#16a085','SITE' => '#27ae60' }[item[:division]] || '#555'
        "<tr>
          <td style='text-align:center;color:#888;'>#{i}</td>
          <td><span style='background:#{div_color};color:#fff;border-radius:3px;padding:1px 6px;font-size:10px;margin-right:4px;'>#{item[:division]}</span>#{item[:entity_name]}</td>
          <td style='font-size:11px;color:#555;'>#{item[:category]}</td>
          <td style='font-size:11px;color:#555;'>#{item[:spec]}</td>
          <td style='text-align:center;'>#{item[:unit]}</td>
          <td style='text-align:right;font-weight:600;color:#c0392b;'>#{qty_fmt}</td>
        </tr>"
      end.join

      <<~HTML
        <!DOCTYPE html><html lang="th"><head><meta charset="UTF-8">
        <style>
          *{box-sizing:border-box;margin:0;padding:0;font-family:'Segoe UI',Tahoma,sans-serif;}
          body{background:#f4f6f9;color:#2c3e50;font-size:13px;}
          header{background:linear-gradient(135deg,#1a5276,#2980b9);color:#fff;padding:12px 20px;display:flex;justify-content:space-between;align-items:center;}
          header h1{font-size:16px;}
          .project-bar{background:#d5e8f3;padding:5px 20px;font-size:12px;color:#1a5276;}
          .toolbar{display:flex;gap:8px;padding:10px 20px;background:#fff;border-bottom:1px solid #ddd;flex-wrap:wrap;}
          .btn{padding:6px 14px;border:none;border-radius:5px;font-size:12px;cursor:pointer;font-weight:600;}
          .btn-orange{background:#e67e22;color:#fff;} .btn-orange:hover{background:#ca6f1e;}
          .btn-teal{background:#16a085;color:#fff;} .btn-teal:hover{background:#0d8069;}
          .btn-purple{background:#8e44ad;color:#fff;} .btn-purple:hover{background:#703688;}
          .btn-gray{background:#bdc3c7;color:#fff;}
          .content{padding:14px 20px;display:flex;flex-direction:column;gap:16px;}
          .section{background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.08);overflow:hidden;}
          .section-title{background:#34495e;color:#fff;padding:8px 14px;font-size:13px;font-weight:700;}
          table{width:100%;border-collapse:collapse;}
          th{background:#eaf0fb;color:#1a5276;padding:8px 10px;font-size:11px;text-align:left;border-bottom:2px solid #cdd8f0;}
          td{padding:7px 10px;font-size:12px;border-bottom:1px solid #eee;}
          tr.div-header td{font-size:13px;}
          tr:not(.div-header):hover td{background:#f0f7ff;}
          .note{font-size:11px;color:#aaa;padding:8px 14px;text-align:right;}
        </style></head><body>
          <header>
            <h1>📋 ตาราง BOQ — Bill of Quantities</h1>
            <span style="font-size:11px;opacity:.8;">#{Time.now.strftime('%d/%m/%Y')}</span>
          </header>
          <div class="project-bar">🏗️ โครงการ: #{project_name}</div>
          <div class="toolbar">
            <button class="btn btn-purple" onclick="sketchup.costdb()">💰 Cost Database</button>
            <button class="btn btn-orange" onclick="sketchup.excel()">📊 Export Excel</button>
            <button class="btn btn-teal"   onclick="sketchup.pr1()">📄 ปร.1</button>
            <button class="btn btn-teal"   onclick="sketchup.pr4()">📄 ปร.4</button>
            <button class="btn btn-teal"   onclick="sketchup.pr4final()">📄 ปร.4(ราคากลาง)</button>
            <button class="btn btn-teal"   onclick="sketchup.pr5()">📄 ปร.5</button>
            <button class="btn btn-gray"   onclick="sketchup.csv()">📁 CSV</button>
          </div>
          <div class="content">

            <!-- ตาราง BOQ สรุปตาม Division > Category -->
            <div class="section">
              <div class="section-title">📋 สรุปปริมาณงาน (BOQ Summary)</div>
              <table>
                <thead><tr>
                  <th style="width:40px;text-align:center;">ที่</th>
                  <th>รายการ</th>
                  <th>ข้อกำหนด/Spec</th>
                  <th style="width:70px;text-align:center;">หน่วย</th>
                  <th style="width:100px;text-align:right;">ปริมาณ</th>
                  <th style="width:110px;text-align:right;">ราคา/หน่วย</th>
                  <th style="width:120px;text-align:right;">ราคารวม</th>
                </tr></thead>
                <tbody>#{tbody}</tbody>
                <tfoot>
                  <tr style="background:#eaf4fb;font-weight:700;">
                    <td colspan="6" style="text-align:right;padding:10px 12px;color:#1a5276;">รวมมูลค่าทั้งหมด (บาท)</td>
                    <td style="text-align:right;padding:10px 12px;color:#16a085;font-size:14px;">#{format_money(grand_total)}</td>
                  </tr>
                </tfoot>
              </table>
              <div class="note">* ราคาต่อหน่วยดึงจาก Cost Database — แก้ไขได้ที่ปุ่ม 💰 Cost Database</div>
            </div>

            <!-- ตารางรายละเอียดแต่ละชิ้น -->
            <div class="section">
              <div class="section-title">🔍 รายละเอียดปริมาณแยกรายชิ้น (#{results.size} รายการ)</div>
              <table>
                <thead><tr>
                  <th style="width:40px;text-align:center;">ที่</th>
                  <th>ชื่อ Component/Group</th>
                  <th>Category</th>
                  <th>Spec</th>
                  <th style="width:70px;text-align:center;">หน่วย</th>
                  <th style="width:100px;text-align:right;">ปริมาณ</th>
                </tr></thead>
                <tbody>#{detail_rows}</tbody>
              </table>
            </div>

          </div>
        </body></html>
      HTML
    end

    def self.build_division_summary(results)
      summary = {}
      results.each do |item|
        div = item[:division]
        summary[div] ||= { count: 0, categories: Set.new }
        summary[div][:count] += 1
        summary[div][:categories] << item[:category]
      end
      DIVISIONS.filter_map do |div_key, div_val|
        next unless summary[div_key]
        { div: div_key, label: div_val[:label], count: summary[div_key][:count], categories: summary[div_key][:categories].size }
      end
    end

    def self.count_div(results, div)
      results.count { |r| r[:division] == div }
    end

    def self.format_money(amount)
      amount.to_f.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def self.missing_price_warning(flat_rows)
      return '' if flat_rows.empty?

      missing = BOQGenerator.missing_price_count(flat_rows)
      return '' if missing == 0

      <<~HTML
        <div style="background:#fdf3e3;border:1px solid #f0c674;color:#a36b15;border-radius:6px;padding:8px 14px;font-size:12px;margin-bottom:12px;">
          ⚠️ มี #{missing} รายการที่ยังไม่มีราคาในฐานข้อมูล —
          <a href="#" onclick="sketchup.costdb(); return false;" style="color:#1a5276;font-weight:600;">เปิด Cost Database เพื่อเพิ่มราคา</a>
        </div>
      HTML
    end

  end
end
