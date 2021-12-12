package com.fgiron.votosResourceServer.Repositories;

import com.fgiron.votosResourceServer.Models.Eleccion;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 *
 * @author fgiron
 */
public interface EleccionRepository extends JpaRepository<Eleccion, Long> {
   
   @org.springframework.data.jpa.repository.Query("SELECT id, provincia, instante_comienzo, instante_final, id_tipo_eleccion FROM Elecciones WHERE CURRENT_TIMESTAMP BETWEEN instante_comienzo AND instante_final")
   public Eleccion traerEleccionesActivas();
}
