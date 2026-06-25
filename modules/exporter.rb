# BOQ Office - Exporter Module
# ส่งออกข้อมูล BOQ เป็น CSV / Excel / ปร.4 / ปร.5

require 'csv'
require 'fileutils'

module BOQOffice
  module Exporter

    # ---- CSV ----------------------------------------------------------------
    def self.export_csv
      rows = BOQGenerator.to_flat_array
      return UI.messagebox('กรุณา Generate BOQ ก่อน') if rows.empty?

      path = UI.savepanel('บันทึก CSV', Dir.home, 'BOQ_Export.csv')
      return unless path

      CSV.open(path, 'w', encoding: 'UTF-8', write_headers: true,
               headers: %w[ลำดับ หมวดงาน รายการ ข้อกำหนด หน่วย ปริมาณ ค่าวัสดุ/หน่วย ค่าแรง/หน่วย ราคาต่อหน่วย รวมเงิน]) do |csv|
        rows.each do |row|
          next if row[:type] == 'division_header'
          csv << [
            row[:item_no],
            row[:division],
            row[:description],
            row[:spec],
            row[:unit],
            row[:quantity],
            row[:material_price],
            row[:labor_price],
            row[:unit_price],
            row[:total]
          ]
        end
        csv << []
        csv << ['', '', '', '', '', '', '', '', 'รวมทั้งสิ้น', BOQGenerator.grand_total(rows).round(2)]
      end

      missing = BOQGenerator.missing_price_count(rows)
      note = missing > 0 ? "\n⚠️ มี #{missing} รายการที่ยังไม่มีราคาในฐานข้อมูล (คิดเป็น 0 บาท)" : ''
      UI.messagebox("บันทึก CSV สำเร็จ\n#{path}#{note}")
    end

    # ---- Excel (CSV-based, เปิดด้วย Excel ได้) ------------------------------
    def self.export_excel
      rows = BOQGenerator.to_flat_array
      return UI.messagebox('กรุณา Generate BOQ ก่อน') if rows.empty?

      path = UI.savepanel('บันทึก Excel', Dir.home, 'BOQ_Export.csv')
      return unless path

      # เขียน UTF-8 BOM เพื่อให้ Excel เปิดได้ถูกต้อง
      File.open(path, 'w', encoding: 'UTF-8') do |f|
        f.write("\xEF\xBB\xBF") # BOM
        f.write("BOQ OFFICE - ใบแสดงปริมาณงานและราคา\n")
        f.write("โครงการ,#{project_name}\n")
        f.write("วันที่,#{Time.now.strftime('%d/%m/%Y')}\n\n")
        f.write("ลำดับ,หมวดงาน,รายการ,ข้อกำหนด,หน่วย,ปริมาณ,ค่าวัสดุ/หน่วย,ค่าแรง/หน่วย,ราคาต่อหน่วย,รวมเงิน\n")

        rows.each do |row|
          if row[:type] == 'division_header'
            f.write("\n#{row[:label]}\n")
          else
            f.write([
              row[:item_no],
              row[:division],
              row[:description],
              row[:spec],
              row[:unit],
              row[:quantity],
              row[:material_price],
              row[:labor_price],
              row[:unit_price],
              row[:total]
            ].join(',') + "\n")
          end
        end

        f.write("\n,,,,,,,,รวมทั้งสิ้น,#{BOQGenerator.grand_total(rows).round(2)}\n")
      end

      missing = BOQGenerator.missing_price_count(rows)
      note = missing > 0 ? "\n⚠️ มี #{missing} รายการที่ยังไม่มีราคาในฐานข้อมูล (คิดเป็น 0 บาท)\nไปที่ 💰 Cost Database เพื่อเพิ่มราคา" : ''
      UI.messagebox("บันทึก Excel (CSV) สำเร็จ\n#{path}#{note}")
    end

    # ---- ปร.4 ---------------------------------------------------------------
    def self.export_pr4
      rows = BOQGenerator.to_flat_array
      return UI.messagebox('กรุณา Generate BOQ ก่อน') if rows.empty?

      path = UI.savepanel('บันทึก ปร.4', Dir.home, 'PR4_Export.csv')
      return unless path

      File.open(path, 'w', encoding: 'UTF-8') do |f|
        f.write("\xEF\xBB\xBF")
        f.write("แบบ ปร.4 - ใบแสดงรายการวัสดุก่อสร้าง\n")
        f.write("โครงการ,#{project_name}\n")
        f.write("สถานที่ก่อสร้าง,#{ProjectSettings.get('location')}\n")
        f.write("วันที่ประมาณราคา,#{Time.now.strftime('%d/%m/%Y')}\n\n")
        f.write("ลำดับที่,รายการ,ข้อกำหนดพิเศษ,หน่วย,ปริมาณ,ราคา/หน่วย,ราคารวม,หมายเหตุ\n")

        rows.each do |row|
          if row[:type] == 'division_header'
            f.write("\nหมวดที่ #{row[:division]},,,,,,, #{row[:label]}\n")
          else
            note = row[:has_price] ? '' : 'ยังไม่มีราคา'
            f.write([
              row[:item_no],
              row[:description],
              row[:spec],
              row[:unit],
              format_qty(row[:quantity]),
              row[:unit_price],
              row[:total],
              note
            ].join(',') + "\n")
          end
        end

        f.write("\nรวมทั้งสิ้น (บาท),,,,,,#{BOQGenerator.grand_total(rows).round(2)},\n")
        f.write("ผู้ประมาณราคา,,,,,,,\n")
        f.write("ตำแหน่ง,,,,,,,\n")
        f.write("วันที่,,,,,,,\n")
      end

      missing = BOQGenerator.missing_price_count(rows)
      note = missing > 0 ? "\n⚠️ มี #{missing} รายการที่ยังไม่มีราคาในฐานข้อมูล" : ''
      UI.messagebox("บันทึก ปร.4 สำเร็จ\n#{path}#{note}")
    end

    # ---- ปร.5 ---------------------------------------------------------------
    def self.export_pr5
      rows = BOQGenerator.to_flat_array
      return UI.messagebox('กรุณา Generate BOQ ก่อน') if rows.empty?

      path = UI.savepanel('บันทึก ปร.5', Dir.home, 'PR5_Export.csv')
      return unless path

      grand_total = BOQGenerator.grand_total(rows)
      ff          = FactorFCalculator.apply(grand_total)

      File.open(path, 'w', encoding: 'UTF-8') do |f|
        f.write("\xEF\xBB\xBF")
        f.write("แบบ ปร.5 - สรุปราคากลางงานก่อสร้าง\n")
        f.write("โครงการ,#{project_name}\n")
        f.write("สถานที่ก่อสร้าง,#{ProjectSettings.get('location')}\n")
        f.write("ประเภทงาน,งานก่อสร้างอาคาร\n")
        f.write("วันที่,#{Time.now.strftime('%d/%m/%Y')}\n\n")

        # ปร.5 จัดกลุ่มตาม Division
        f.write("หมวดงาน,รายละเอียด,ราคารวม (บาท)\n")

        DIVISIONS.each_key do |div|
          div_rows = rows.select { |r| r[:type] == 'item' && r[:division] == div }
          next if div_rows.empty?

          div_label   = DIVISIONS[div][:label]
          div_total   = div_rows.sum { |r| r[:total].to_f }
          f.write("#{div} - #{div_label},,#{div_total.round(2)}\n")

          div_rows.each do |row|
            f.write(",#{row[:description]} (#{row[:quantity]} #{row[:unit]}),#{row[:total]}\n")
          end

          f.write(",รวมหมวด #{div},#{div_total.round(2)}\n\n")
        end

        f.write("รวมค่าก่อสร้าง (ค่างานต้นทุน A),,#{grand_total.round(2)}\n")
        f.write("ค่า Factor F,,#{ff[:factor]}\n")
        f.write("หมายเหตุการคำนวณ Factor F,,#{ff[:note]}\n")
        f.write("ราคากลางงานก่อสร้าง (A x Factor F),,#{ff[:total]}\n\n")
        f.write("ผู้คำนวณราคากลาง,,#{ProjectSettings.get('calculated_by')}\n")
        write_committee_rows(f)
      end

      missing = BOQGenerator.missing_price_count(rows)
      note = missing > 0 ? "\n⚠️ มี #{missing} รายการที่ยังไม่มีราคาในฐานข้อมูล (ยอดรวมนี้ยังไม่สมบูรณ์)" : ''
      UI.messagebox("บันทึก ปร.5 สำเร็จ\n#{path}\nFactor F = #{ff[:factor]} → ราคากลาง #{format_money(ff[:total])} บาท#{note}")
    end

    # ---- ปร.1 (รายการวัสดุ/ค่าแรงละเอียดต่อรายการ) ---------------------------
    def self.export_pr1
      rows = BOQGenerator.to_flat_array
      return UI.messagebox('กรุณา Generate BOQ ก่อน') if rows.empty?

      path = UI.savepanel('บันทึก ปร.1', Dir.home, 'PR1_Export.csv')
      return unless path

      File.open(path, 'w', encoding: 'UTF-8') do |f|
        f.write("\xEF\xBB\xBF")
        f.write("แบบแสดงรายการ ปริมาณงาน และราคา (ปร.1)\n")
        f.write("ชื่อโครงการ,#{project_name}\n")
        f.write("สถานที่ก่อสร้าง,#{ProjectSettings.get('location')}\n")
        f.write("หน่วยงานเจ้าของโครงการ,#{ProjectSettings.get('owner_org')}\n")
        f.write("แบบเลขที่,#{ProjectSettings.get('drawing_no')}\n")
        f.write("คำนวณราคากลางโดย,#{ProjectSettings.get('calculated_by')}\n")
        f.write("เมื่อวันที่,#{Time.now.strftime('%d/%m/%Y')}\n\n")
        f.write("หน่วย : บาท\n")
        f.write("ลำดับ,รายการ,จำนวน,หน่วย,ราคาวัสดุ/หน่วย,ค่าวัสดุรวม,ค่าแรง/หน่วย,ค่าแรงรวม,ราคารวม,หมายเหตุ\n")

        div_no = 0
        DIVISIONS.each_key do |div|
          div_rows = rows.select { |r| r[:type] == 'item' && r[:division] == div }
          next if div_rows.empty?

          div_no += 1
          div_label = DIVISIONS[div][:label]
          f.write("#{div_no},#{div} - #{div_label}\n")

          div_rows.each do |row|
            material_total = (row[:quantity] * row[:material_price]).round(2)
            labor_total     = (row[:quantity] * row[:labor_price]).round(2)
            note = row[:has_price] ? '' : 'ยังไม่มีราคา'
            f.write([
              '',
              " - #{row[:description]}",
              format_qty(row[:quantity]),
              row[:unit],
              row[:material_price],
              material_total,
              row[:labor_price],
              labor_total,
              row[:total],
              note
            ].join(',') + "\n")
          end

          div_total = div_rows.sum { |r| r[:total].to_f }
          f.write(",รวม#{div_label},,,,,,,#{div_total.round(2)}\n\n")
        end

        f.write(",รวมค่าก่อสร้างทั้งสิ้น,,,,,,,#{BOQGenerator.grand_total(rows).round(2)}\n")
      end

      missing = BOQGenerator.missing_price_count(rows)
      note = missing > 0 ? "\n⚠️ มี #{missing} รายการที่ยังไม่มีราคาในฐานข้อมูล" : ''
      UI.messagebox("บันทึก ปร.1 สำเร็จ\n#{path}#{note}")
    end

    # ---- ปร.4 (ราคากลาง) - สรุปยอดสุดท้ายพร้อม Factor F ----------------------
    def self.export_pr4_final
      rows = BOQGenerator.to_flat_array
      return UI.messagebox('กรุณา Generate BOQ ก่อน') if rows.empty?

      path = UI.savepanel('บันทึก ปร.4 (ราคากลาง)', Dir.home, 'PR4_Final_Export.csv')
      return unless path

      grand_total = BOQGenerator.grand_total(rows)
      ff          = FactorFCalculator.apply(grand_total)

      File.open(path, 'w', encoding: 'UTF-8') do |f|
        f.write("\xEF\xBB\xBF")
        f.write("แบบสรุปราคากลางงานก่อสร้างอาคาร (ปร.4)\n")
        f.write("ชื่อโครงการ,#{project_name}\n")
        f.write("สถานที่ก่อสร้าง,#{ProjectSettings.get('location')}\n")
        f.write("หน่วยงานเจ้าของโครงการ,#{ProjectSettings.get('owner_org')}\n")
        f.write("แบบเลขที่,#{ProjectSettings.get('drawing_no')}\n")
        f.write("คำนวณราคากลางโดย,#{ProjectSettings.get('calculated_by')}\n")
        f.write("เมื่อวันที่,#{Time.now.strftime('%d/%m/%Y')}\n\n")
        f.write("หน่วย : บาท\n\n")

        f.write("ลำดับที่,รายการ,ค่างานต้นทุน (A),หมายเหตุ\n")
        f.write("1,ส่วนที่ 1 ค่าก่อสร้างประเภทงานอาคาร,#{grand_total.round(2)}\n\n")

        f.write("สรุป,,\n")
        f.write("รวมค่างานต้นทุนทั้งโครงการ (A),,#{grand_total.round(2)}\n")
        f.write("ค่า Factor F,,#{ff[:factor]}\n")
        f.write("วิธีคำนวณ Factor F,,#{ff[:note]}\n")
        f.write("ราคากลางงานก่อสร้าง (A x Factor F),,#{ff[:total]}\n")
        f.write("ราคากลาง (ตัวอักษร),,#{number_to_thai_text(ff[:total])}\n\n")

        f.write("หมายเหตุ\n")
        ref = ProjectSettings.get('price_ref')
        f.write("#{ref.empty? ? 'ราคาเฉลี่ยวัสดุก่อสร้าง ณ วันที่คำนวณ' : ref}\n\n")

        f.write("คณะกรรมการกำหนดราคากลาง\n")
        write_committee_rows(f)
      end

      missing = BOQGenerator.missing_price_count(rows)
      note = missing > 0 ? "\n⚠️ มี #{missing} รายการที่ยังไม่มีราคาในฐานข้อมูล (ราคากลางนี้ยังไม่สมบูรณ์)" : ''
      UI.messagebox("บันทึก ปร.4 (ราคากลาง) สำเร็จ\n#{path}\n\nค่างานต้นทุน A = #{format_money(grand_total)} บาท\nFactor F = #{ff[:factor]}\nราคากลาง = #{format_money(ff[:total])} บาท#{note}")
    end

    private

    def self.project_name
      ProjectSettings.project_name
    end

    def self.format_qty(qty)
      qty == qty.to_i ? qty.to_i.to_s : format('%.3f', qty)
    end

    def self.format_money(amount)
      amount.to_f.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
    end

    def self.write_committee_rows(f)
      committee = ProjectSettings.get('committee') || []
      if committee.empty?
        f.write("ลำดับ,ชื่อ-สกุล,ตำแหน่ง\n")
        f.write("1,,\n2,,\n3,,\n")
      else
        f.write("ลำดับ,ชื่อ-สกุล,ตำแหน่ง\n")
        committee.each_with_index do |m, i|
          f.write("#{i + 1},#{m['name']},#{m['position']}\n")
        end
      end
    end

    # แปลงตัวเลขเป็นคำอ่านภาษาไทย (บาท/สตางค์) แบบพื้นฐาน
    DIGIT_TH = %w[ศูนย์ หนึ่ง สอง สาม สี่ ห้า หก เจ็ด แปด เก้า].freeze
    UNIT_TH  = ['', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน', 'ล้าน'].freeze

    def self.number_to_thai_text(amount)
      baht   = amount.to_i
      satang = ((amount - baht) * 100).round

      text = "#{thai_digits(baht)}บาท"
      text += satang > 0 ? "#{thai_digits(satang)}สตางค์" : "ถ้วน"
      text
    rescue
      ''
    end

    def self.thai_digits(num)
      return DIGIT_TH[0] if num.zero?

      # แบ่งเป็นกลุ่มล้าน (ล้านของล้าน รองรับเลขใหญ่ด้วยการวนซ้ำ)
      millions, remainder = num.divmod(1_000_000)
      result = millions > 0 ? "#{thai_digits(millions)}ล้าน" : ''
      result + thai_six_digit(remainder)
    end

    def self.thai_six_digit(num)
      return '' if num.zero?

      digits = num.to_s.chars.map(&:to_i)
      len = digits.length
      out = ''

      digits.each_with_index do |d, idx|
        place = len - idx - 1 # 0 = หน่วย, 1 = สิบ, ...
        next if d.zero?

        if place == 0
          out += (d == 1 && len > 1) ? 'เอ็ด' : DIGIT_TH[d]
        elsif place == 1
          out += (d == 1) ? 'สิบ' : (d == 2 ? 'ยี่สิบ' : "#{DIGIT_TH[d]}สิบ")
        else
          out += "#{DIGIT_TH[d]}#{UNIT_TH[place] || ''}"
        end
      end

      out
    end

  end
end
