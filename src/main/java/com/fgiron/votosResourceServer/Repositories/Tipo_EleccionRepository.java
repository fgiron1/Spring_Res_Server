package com.fgiron.votosResourceServer.Repositories;

import com.fgiron.votosResourceServer.Models.Tipo_Eleccion;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 *
 * @author fgiron
 */

public interface Tipo_EleccionRepository extends JpaRepository<Tipo_Eleccion, Long>{
    
}
