/*

 */
package com.fgiron.votosResourceServer.Repositories;
import com.fgiron.votosResourceServer.Models.Eleccion;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 *
 * @author fgiron
 */
public interface EleccionRepository extends JpaRepository<Eleccion, Long> {
    
   // public Eleccion traerEleccionesActivas();
}
