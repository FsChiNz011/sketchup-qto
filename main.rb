# BOQ Office - Main Entry Point
require 'sketchup.rb'
require 'json'

module BOQOffice

  DIVISIONS = {
    'ARCH' => {
      label: 'งานสถาปัตยกรรม',
      categories: {
        'Wall'          => { label: 'ผนัง',          unit: 'm2', method: 'Area'   },
        'Floor_Finish'  => { label: 'งานพื้น',        unit: 'm2', method: 'Area'   },
        'Ceiling'       => { label: 'ฝ้าเพดาน',       unit: 'm2', method: 'Area'   },
        'Roof'          => { label: 'หลังคา',          unit: 'm2', method: 'Area'   },
        'Door'          => { label: 'ประตู',           unit: 'set', method: 'Count'  },
        'Window'        => { label: 'หน้าต่าง',        unit: 'set', method: 'Count'  },
        'Painting'      => { label: 'งานทำสี',         unit: 'm2', method: 'Area'   },
        'Waterproofing' => { label: 'งานกันซึม',       unit: 'm2', method: 'Area'   },
        'Railing'       => { label: 'ราวกันตก',        unit: 'm',  method: 'Length' },
        'Decoration'    => { label: 'งานตกแต่ง',       unit: 'set', method: 'Count'  }
      }
    },
    'STR' => {
      label: 'งานวิศวกรรมโครงสร้าง',
      categories: {
        'Foundation'     => { label: 'ฐานราก',         unit: 'm3', method: 'Volume' },
        'Pedestal'       => { label: 'ตอม่อ',           unit: 'm3', method: 'Volume' },
        'Column'         => { label: 'เสา',             unit: 'm3', method: 'Volume' },
        'Beam'           => { label: 'คาน',             unit: 'm3', method: 'Volume' },
        'Slab'           => { label: 'พื้น',            unit: 'm3', method: 'Volume' },
        'Stair'          => { label: 'บันได',           unit: 'm3', method: 'Volume' },
        'Retaining_Wall' => { label: 'กำแพงกันดิน',     unit: 'm3', method: 'Volume' },
        'Footing_Tie_Beam'=> { label: 'คานคอดิน',      unit: 'm3', method: 'Volume' },
        'Roof_Structure' => { label: 'โครงสร้างหลังคา', unit: 'kg', method: 'Volume' },
        'Concrete_Work'  => { label: 'งานคอนกรีต',     unit: 'm3', method: 'Volume' },
        'Reinforcement'  => { label: 'เหล็กเสริม',     unit: 'kg', method: 'Volume' },
        'Formwork'       => { label: 'แบบหล่อ',        unit: 'm2', method: 'Area'   }
      }
    },
    'ELEC' => {
      label: 'งานไฟฟ้าและสื่อสาร',
      categories: {
        'Lighting'            => { label: 'ระบบแสงสว่าง',        unit: 'point', method: 'Count' },
        'Power_Outlet'        => { label: 'เต้ารับไฟฟ้า',         unit: 'point', method: 'Count' },
        'Switch'              => { label: 'สวิตช์ไฟฟ้า',          unit: 'point', method: 'Count' },
        'Conduit'             => { label: 'ท่อร้อยสายไฟ',         unit: 'm',     method: 'Length'},
        'Cable'               => { label: 'สายไฟฟ้า',             unit: 'm',     method: 'Length'},
        'MDB'                 => { label: 'ตู้เมนไฟฟ้า',          unit: 'set',   method: 'Count' },
        'DB'                  => { label: 'ตู้ย่อยไฟฟ้า',         unit: 'set',   method: 'Count' },
        'CCTV'                => { label: 'กล้องวงจรปิด',          unit: 'point', method: 'Count' },
        'Communication'       => { label: 'ระบบสื่อสาร',          unit: 'point', method: 'Count' },
        'Fire_Alarm'          => { label: 'ระบบแจ้งเหตุเพลิงไหม้', unit: 'point', method: 'Count' },
        'Lightning_Protection'=> { label: 'ระบบป้องกันฟ้าผ่า',    unit: 'set',   method: 'Count' }
      }
    },
    'SAN' => {
      label: 'งานสุขาภิบาลและเครื่องกล',
      categories: {
        'Water_Supply'    => { label: 'ระบบประปา',          unit: 'm',   method: 'Length' },
        'Drainage'        => { label: 'ระบบระบายน้ำ',        unit: 'm',   method: 'Length' },
        'Sanitary_Fixture'=> { label: 'สุขภัณฑ์',           unit: 'set', method: 'Count'  },
        'Septic_Tank'     => { label: 'ถังบำบัดน้ำเสีย',     unit: 'set', method: 'Count'  },
        'Water_Tank'      => { label: 'ถังเก็บน้ำ',          unit: 'set', method: 'Count'  },
        'Water_Pump'      => { label: 'ปั๊มน้ำ',             unit: 'set', method: 'Count'  },
        'Fire_Protection' => { label: 'ระบบดับเพลิง',        unit: 'set', method: 'Count'  },
        'HVAC'            => { label: 'ระบบปรับอากาศ',       unit: 'set', method: 'Count'  },
        'Ventilation'     => { label: 'ระบบระบายอากาศ',      unit: 'm2',  method: 'Area'   }
      }
    },
    'SITE' => {
      label: 'งานภายนอกอาคาร',
      categories: {
        'Concrete_Road' => { label: 'ถนนคอนกรีต', unit: 'm2', method: 'Area'   },
        'Asphalt_Road'  => { label: 'ถนนแอสฟัลต์', unit: 'm2', method: 'Area'   },
        'Sidewalk'      => { label: 'ทางเท้า',      unit: 'm2', method: 'Area'   },
        'Fence'         => { label: 'รั้ว',          unit: 'm',  method: 'Length' },
        'Gate'          => { label: 'ประตูรั้ว',     unit: 'set', method: 'Count' },
        'Drain'         => { label: 'รางระบายน้ำ',  unit: 'm',  method: 'Length' },
        'Manhole'       => { label: 'บ่อพัก',        unit: 'set', method: 'Count' },
        'Culvert'       => { label: 'ท่อลอด',       unit: 'm',  method: 'Length' },
        'Landscape'     => { label: 'ภูมิสถาปัตย์', unit: 'm2', method: 'Area'   },
        'Parking'       => { label: 'ลานจอดรถ',     unit: 'm2', method: 'Area'   }
      }
    }
  }

  # ==============================
  # MENU SETUP
  # ==============================
  unless file_loaded?(__FILE__)
    require_relative 'modules/scanner'
    require_relative 'modules/project_settings'
    require_relative 'modules/cost_database'
    require_relative 'modules/factor_f_calculator'
    require_relative 'modules/boq_generator'
    require_relative 'modules/exporter'
    require_relative 'dialogs/dashboard'
    require_relative 'dialogs/assign_dialog'
    require_relative 'dialogs/cost_database_dialog'
    require_relative 'dialogs/settings_dialog'

    menu = UI.menu('Extensions').add_submenu('BOQ Office')
    menu.add_item('📊 Dashboard')        { BOQOffice::Dashboard.show }
    menu.add_separator
    menu.add_item('🏷️ Assign Category')  { BOQOffice::AssignDialog.show }
    menu.add_item('🔍 Scan Model')       { BOQOffice::Scanner.scan_model }
    menu.add_item('📋 Generate BOQ')     { BOQOffice::BOQGenerator.generate }
    menu.add_item('💰 Cost Database')    { BOQOffice::CostDatabaseDialog.show }
    menu.add_separator
    menu.add_item('📁 Export CSV')             { BOQOffice::Exporter.export_csv }
    menu.add_item('📊 Export Excel')           { BOQOffice::Exporter.export_excel }
    menu.add_item('📄 Export ปร.1')            { BOQOffice::Exporter.export_pr1 }
    menu.add_item('📄 Export ปร.4')            { BOQOffice::Exporter.export_pr4 }
    menu.add_item('📄 Export ปร.4 (ราคากลาง)') { BOQOffice::Exporter.export_pr4_final }
    menu.add_item('📄 Export ปร.5')            { BOQOffice::Exporter.export_pr5 }
    menu.add_separator
    menu.add_item('⚙️ Settings')         { BOQOffice::SettingsDialog.show }
    menu.add_item('ℹ️ About')            { BOQOffice::Dashboard.show_about }

    file_loaded(__FILE__)
  end

end
