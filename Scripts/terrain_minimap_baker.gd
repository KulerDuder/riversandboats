class_name TerrainMinimapBaker
extends RefCounted
## Genera la imagen y textura del minimapa a partir de la SDF del terreno.


static func bake_texture(sd: PackedFloat32Array, grid_cells: int, border_cells: int, river_half_width: float, water_margin: float) -> ImageTexture:
	var img: Image = bake_image(sd, grid_cells, border_cells, river_half_width, water_margin)
	return ImageTexture.create_from_image(img)


static func bake_image(sd: PackedFloat32Array, grid_cells: int, border_cells: int, river_half_width: float, water_margin: float) -> Image:
	var n: int = grid_cells
	var v: int = n + 1
	var img: Image = Image.create(v, v, false, Image.FORMAT_RGBA8)

	if sd.is_empty():
		img.fill(Color(0.12, 0.40, 0.74))
		return img

	var border_f: float = float(border_cells)
	var half_w: float = river_half_width

	for j: int in v:
		for i: int in v:
			var k: int = j * v + i
			var s: float = sd[k]

			# Distancia al borde del mapa
			var edge_dist: float = float(mini(mini(i, j), mini(n - i, n - j)))
			var edge_factor: float = smoothstep(0.0, border_f, edge_dist)

			var col: Color
			if edge_factor < 0.30:
				# Océano exterior profundo que rodea la isla
				var ocean_deep := Color(0.08, 0.22, 0.44)
				var ocean_coast := Color(0.14, 0.45, 0.75)
				col = ocean_deep.lerp(ocean_coast, edge_factor / 0.30)
			elif s < -water_margin:
				# Agua de río navegable: azul vibrante, cristalino y profundo
				var depth: float = clampf((-s - water_margin) / (half_w * 0.9), 0.0, 1.0)
				var shallow_blue := Color(0.25, 0.65, 0.95)   # Agua somera en orilla
				var deep_blue := Color(0.10, 0.38, 0.75)      # Canal profundo central
				col = shallow_blue.lerp(deep_blue, depth)

				# Línea de espuma / agua brillante en la orilla
				if s > -0.6:
					var foam_t: float = smoothstep(-0.6, -water_margin, s)
					col = col.lerp(Color(0.70, 0.92, 1.0), foam_t * 0.6)
			else:
				# Tierra firme (s >= -water_margin)
				var land_dist: float = s + water_margin
				if land_dist < 1.2:
					# Ribera / playa de arena a lo largo de todo el curso del río
					var t: float = land_dist / 1.2
					var wet_sand := Color(0.85, 0.78, 0.58)
					var dry_sand := Color(0.92, 0.86, 0.65)
					var grass_edge := Color(0.52, 0.74, 0.36)
					col = wet_sand.lerp(dry_sand, t).lerp(grass_edge, t * 0.4)
				else:
					# Praderas y vegetación interior
					var t: float = clampf((land_dist - 1.2) / 8.0, 0.0, 1.0)
					var meadow_green := Color(0.36, 0.66, 0.28)  # Pradera brillante
					var forest_green := Color(0.24, 0.50, 0.22)  # Bosque denso
					col = meadow_green.lerp(forest_green, t)

					# Zonas altas / colinas rocosas
					if land_dist > 6.0:
						var rock_t: float = clampf((land_dist - 6.0) / 10.0, 0.0, 1.0)
						var rock_col := Color(0.50, 0.48, 0.44)
						col = col.lerp(rock_col, rock_t * 0.65)

				# Transición suave hacia el mar en los bordes de la isla
				if edge_factor < 1.0:
					var coastal_water := Color(0.14, 0.45, 0.75)
					col = coastal_water.lerp(col, edge_factor)

			img.set_pixel(i, j, col)

	return img
