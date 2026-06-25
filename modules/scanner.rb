# BOQ Office - Scanner Module
# ทำหน้าที่สแกนโมเดล SketchUp และอ่าน Attribute Dictionary

module BOQOffice
  module Scanner

    # สแกนโมเดลทั้งหมด และส่งค่ากลับเป็น Array of Hash
    def self.scan_model
      model = Sketchup.active_model
      return UI.messagebox('ไม่พบโมเดล กรุณาเปิดโมเดล SketchUp ก่อน') unless model

      results = []
      entities = model.active_entities

      traverse_entities(entities, results, Geom::Transformation.new)

      if results.empty?
        UI.messagebox("ไม่พบ Component/Group ที่มี BOQ Metadata\nกรุณา Assign Category ก่อนทำการ Scan")
      else
        UI.messagebox("สแกนสำเร็จ พบข้อมูล #{results.size} รายการ\nกด OK เพื่อดู Dashboard")
        BOQOffice::Dashboard.show(results)
      end

      results
    end

    # วนซ้ำ entities รวมถึง nested groups/components
    def self.traverse_entities(entities, results, transform)
      entities.each do |ent|
        case ent
        when Sketchup::Group, Sketchup::ComponentInstance
          dict = ent.attribute_dictionary('boq_office', false)
          if dict
            data = read_metadata(ent, dict, transform)
            results << data if data
          end
          # วนเข้าไปใน nested entities
          sub_entities = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
          sub_transform = transform * ent.transformation
          traverse_entities(sub_entities, results, sub_transform)
        end
      end
    end

    # อ่าน metadata และคำนวณปริมาณ
    def self.read_metadata(entity, dict, transform)
      division = dict['division']
      category = dict['category']
      unit     = dict['unit']
      spec     = dict['spec'] || ''
      desc     = dict['description'] || entity_label(entity)

      return nil unless division && category && unit

      quantity = calculate_quantity(entity, unit, transform)

      {
        division:    division,
        category:    category,
        unit:        unit,
        spec:        spec,
        description: desc,
        quantity:    quantity.round(3),
        entity_name: entity_label(entity)
      }
    end

    # คำนวณปริมาณตามหน่วย
    def self.calculate_quantity(entity, unit, transform)
      bounds = entity.bounds

      case unit
      when 'm3'
        volume_m3(bounds, transform)
      when 'm2'
        area_m2(bounds, transform)
      when 'm'
        length_m(bounds, transform)
      when 'kg'
        # เหล็กเสริม: คำนวณจาก volume * density (7850 kg/m3)
        volume_m3(bounds, transform) * 7850.0
      else
        # Count: นับ 1 ต่อ entity
        1.0
      end
    end

    def self.volume_m3(bounds, transform)
      w = bounds.width.to_m
      h = bounds.height.to_m
      d = bounds.depth.to_m
      (w * h * d).abs
    end

    def self.area_m2(bounds, transform)
      # ใช้พื้นที่หน้าตัดที่ใหญ่ที่สุด
      w = bounds.width.to_m
      h = bounds.height.to_m
      d = bounds.depth.to_m
      [w * h, w * d, h * d].max.abs
    end

    def self.length_m(bounds, transform)
      # ใช้ด้านที่ยาวที่สุด
      w = bounds.width.to_m
      h = bounds.height.to_m
      d = bounds.depth.to_m
      [w, h, d].max.abs
    end

    def self.entity_label(entity)
      if entity.is_a?(Sketchup::ComponentInstance)
        entity.definition.name
      else
        entity.name.empty? ? 'Group' : entity.name
      end
    end

    # ดึงผลลัพธ์ล่าสุดที่ถูก scan ไว้
    def self.last_results
      @last_results ||= []
    end

    def self.store_results(results)
      @last_results = results
    end

  end
end
