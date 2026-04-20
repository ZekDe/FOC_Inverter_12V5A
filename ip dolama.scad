/**
 * @file    besik_sallama_aparat.scad
 * @brief   Motor şaftına takılan ip sarım aparatı
 *          4 silindirli yapı: şaft tutucu + 2x flanş + parabolik sarım bölgesi
 * @date    09.04.2026
 */

// ============================================================
// GENEL PARAMETRELER
// ============================================================

$fn = 64;   // Pürüzsüz yüzey için yüksek çözünürlük

// Şaft
shaft_d          = 6;   // Motor şaft çapı + 0.2mm baskı toleransı

// Vida delikleri
bolt_d_pos       = 4;     // +X tarafı vida deliği çapı
bolt_d_neg       = 4;     // -X tarafı vida deliği çapı
nut_across_flat  = 5.8;   // M4 somun flat-to-flat + 0.3mm tolerans
nut_depth        = 2.5;   // M4 somun yüksekliği

// Sil.1 - Şaft tutucu
s1_outer_d       = 15;
s1_length        = 20;    // Eski Sil.1 (20mm) + Sil.2 flanş (5mm) birleştirildi
shaft_hole_depth = 15;    // Şaft deliği derinliği

// Sil.2 ve Sil.4 - Flanşlar
flange_d         = 15;
flange_length    = 5;

// Sil.3 - Parabolik sarım bölgesi
s3_length        = 15;
s3_edge_r        = 5;     // Kenar yarıçapı  → çap 10mm
s3_mid_r         = 3.5;   // Orta yarıçapı   → çap 7mm
spool_steps      = 60;    // Parabolik profil çözünürlüğü

// Sil.3 - İp geçiş deliği
rope_hole_d      = 2.2;     // İp delik çapı (mm)
rope_hole_z      = 2.5;   // Delik merkezi Z konumu (ilk 5mm'nin ortası)

// Kenar yuvarlama (Sil.1 üst dış kenar + Sil.3 alt dış kenar)
edge_r           = 2;     // Dış kenar yuvarlama yarıçapı (mm)

// ============================================================
// 1. SİLİNDİR — Şaft Tutucu
// Dış: D=10mm, L=20mm
// İç:  5.2mm delik, 10mm derin (alttan)
// Yan: M3 vida + somun yuvası (şaft deliğinin bittiği noktanın üstünde)
// ============================================================
module createShaftHolder()
{
   // Vida merkezinin Z konumu: şaftın ilk 5mm'sinde (şaft deliği içinde)
   bolt_z = 10;

   r_outer = s1_outer_d / 2;

   difference()
   {
      // --- Dış gövde (üst dış kenar yuvarlanmış) ---
      rotate_extrude(angle = 360)
         polygon(concat(
            [[0, 0],
             [r_outer, 0]],
            [for (a = [0 : 90/16 : 90])
               [r_outer - edge_r + edge_r * cos(a),
                s1_length - edge_r + edge_r * sin(a)]
            ],
            [[0, s1_length]]
         ));

      // --- Şaft deliği (alttan, 10mm derin) ---
      translate([0, 0, -0.1])
         cylinder(d = shaft_d, h = shaft_hole_depth + 0.1);

      // --- Vida deliği (+X tarafı, dış yüzeyden merkeze kadar) ---
      translate([s1_outer_d / 2 + 0.1, 0, bolt_z])
         rotate([0, -90, 0])
            cylinder(d = bolt_d_pos, h = s1_outer_d / 2 + 0.1);

      // --- Vida deliği (-X tarafı, dış yüzeyden merkeze kadar) ---
      translate([-(s1_outer_d / 2 + 0.1), 0, bolt_z])
         rotate([0, 90, 0])
            cylinder(d = bolt_d_neg, h = s1_outer_d / 2 + 0.1);
   }
}

// ============================================================
// 2. ve 4. SİLİNDİR — Flanş (ip durdurucu)
// Dış: D=15mm, L=5mm  |  Düz silindir, delik yok
// ============================================================
module createFlange()
{
   r_outer = flange_d / 2;

   // Alt dış kenar yuvarlanmış (spool ile birleşim tarafı)
   rotate_extrude(angle = 360)
      polygon(concat(
         [[0, 0]],
         [for (a = [-90 : 90/16 : 0])
            [r_outer - edge_r + edge_r * cos(a),
             edge_r + edge_r * sin(a)]
         ],
         [[r_outer, flange_length],
          [0, flange_length]]
      ));
}

// ============================================================
// 3. SİLİNDİR — Parabolik İp Sarım Bölgesi
// Dış: kenar D=10mm, orta D=7mm, L=15mm
// rotate_extrude + parabol fonksiyonu ile üretilir
// ============================================================
module createSpoolBody()
{
   difference()
   {
      // --- Parabolik gövde ---
      rotate_extrude(angle = 360)
         polygon(
            points = concat(
               // İç hat: eksen boyunca kapalı polygon için
               [[0, 0], [0, s3_length]],

               // Dış hat: üstten aşağı, parabolik profil
               // r(t) = r_mid + (r_edge - r_mid) * (2t - 1)^2
               // t=0 → üst kenar (r_edge), t=0.5 → orta (r_mid), t=1 → alt kenar (r_edge)
               [for (i = [spool_steps : -1 : 0])
                  let(
                     t = i / spool_steps,
                     z = t * s3_length,
                     r = s3_mid_r + (s3_edge_r - s3_mid_r) * pow(2 * t - 1, 2)
                  )
                  [r, z]
               ]
            )
         );

      // --- Radyal ip geçiş deliği (ilk 5mm içinde, her iki yandan tam geçen) ---
      translate([-(s3_edge_r + 1), 0, rope_hole_z])
         rotate([0, 90, 0])
            cylinder(d = rope_hole_d, h = (s3_edge_r + 1) * 2);
   }
}

// ============================================================
// ANA MODÜL — Aparatı Z ekseninde birleştir
// Sıra: Sil.1 → Sil.2 → Sil.3 → Sil.4
// ============================================================
module assembleRocker()
{
   // Sil.1 — Şaft tutucu + flanş birleşik (Z=0'dan başlar)
   createShaftHolder();

   // Sil.2 — Parabolik sarım bölgesi
   translate([0, 0, s1_length])
      createSpoolBody();

   // Sil.3 — Dış taraf flanş
   translate([0, 0, s1_length + s3_length])
      createFlange();
}

// ============================================================
// ÇALIŞTIR
// ============================================================
assembleRocker();
