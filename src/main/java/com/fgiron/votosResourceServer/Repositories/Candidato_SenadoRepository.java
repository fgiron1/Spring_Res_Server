package com.fgiron.votosResourceServer.Repositories;

import com.fgiron.votosResourceServer.Models.Candidato_Senado;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 *
 * @author root
 */
public interface Candidato_SenadoRepository  extends JpaRepository<Candidato_Senado, Long>{
    
}
