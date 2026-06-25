# BOQ Office - BOQ Generator Module
# รวบรวมและสรุปปริมาณงานเป็น BOQ Table

module BOQOffice
  module BOQGenerator

    # สร้าง BOQ จากผลลัพธ์การสแกน
    def self.generate(scan_results = nil)
      results = scan_results || Scanner.last_results

      if results.nil? || results.empty?
        answer = UI.messagebox(
          'ยังไม่มีข้อมูลการสแกน\nต้องการ Scan Model ก่อนหรือไม่?',
          MB_YESNO
        )
        if answer == IDYES
          results = Scanner.scan_model
          return if results.nil? || results.empty?
        else
          return
        end
      end

      boq = build_boq(results)
      Scanner.store_results(results)
      @last_boq = boq

      Dashboard.show_boq(boq)
      boq
    end

    # สร้าง BOQ structure จัดกลุ่มตาม division > category
    def self.build_boq(results)
      boq = {}

      results.each do |item|
        div  = item[:division]
        cat  = item[:category]
        unit = item[:unit]
        qty  = item[:quantity].to_f
        spec = item[:spec]

        boq[div] ||= {}
        boq[div][cat] ||= {}

        key = spec.empty? ? 'ทั่วไป' : spec
        boq[div][cat][key] ||= { unit: unit, quantity: 0.0, items: [] }
        boq[div][cat][key][:quantity] += qty
        boq[div][cat][key][:items] << item
      end

      boq
    end

    # แปลง BOQ เป็น Array แบบ flat สำหรับ export
    def self.to_flat_array(boq = nil)
      boq ||= @last_boq
      return [] unless boq

      rows = []
      item_no = 0

      DIVISIONS.each_key do |div|
        next unless boq[div]
        div_info = DIVISIONS[div]

        rows << {
          type:        'division_header',
          division:    div,
          label:       "#{div} - #{div_info[:label]}"
        }

        div_info[:categories].each_key do |cat|
          next unless boq[div][cat]
          cat_info = div_info[:categories][cat]

          boq[div][cat].each do |spec, data|
            item_no += 1
            desc = spec == 'ทั่วไป' ? cat_info[:label] : "#{cat_info[:label]} (#{spec})"

            # ค้นหาราคาจาก Cost Database (spec == 'ทั่วไป' หมายถึงไม่มี spec เฉพาะ)
            lookup_spec = spec == 'ทั่วไป' ? '' : spec
            material    = CostDatabase.material_price(div, cat, lookup_spec)
            labor       = CostDatabase.labor_price(div, cat, lookup_spec)
            unit_price  = material + labor
            quantity    = data[:quantity].round(3)

            rows << {
              type:           'item',
              item_no:        item_no,
              division:       div,
              category:       cat,
              description:    desc,
              spec:           spec,
              unit:           data[:unit],
              quantity:       quantity,
              material_price: material.round(2),
              labor_price:    labor.round(2),
              unit_price:     unit_price.round(2),
              total:          (quantity * unit_price).round(2),
              has_price:      unit_price > 0
            }
          end
        end
      end

      rows
    end

    def self.last_boq
      @last_boq
    end

    # ยอดรวมราคาทั้งหมด (เฉพาะรายการที่มีราคาในฐานข้อมูลแล้ว)
    def self.grand_total(rows = nil)
      rows ||= to_flat_array
      rows.select { |r| r[:type] == 'item' }.sum { |r| r[:total].to_f }
    end

    # ยอดรวมราคาแยกตาม Division (สำหรับ ปร.1 / ปร.4)
    def self.total_by_division(rows = nil)
      rows ||= to_flat_array
      totals = {}
      DIVISIONS.each_key { |div| totals[div] = 0.0 }
      rows.select { |r| r[:type] == 'item' }.each do |r|
        totals[r[:division]] = (totals[r[:division]] || 0.0) + r[:total].to_f
      end
      totals
    end

    # จำนวนรายการที่ยังไม่มีราคา (เพื่อเตือนผู้ใช้ใน Dashboard)
    def self.missing_price_count(rows = nil)
      rows ||= to_flat_array
      rows.select { |r| r[:type] == 'item' }.count { |r| !r[:has_price] }
    end

  end
end
