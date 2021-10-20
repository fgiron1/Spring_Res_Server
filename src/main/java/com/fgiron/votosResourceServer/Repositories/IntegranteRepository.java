package com.fgiron.votosResourceServer.Repositories;

import com.fgiron.votosResourceServer.Models.Integrante;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 *
 * @author root
 */
public interface IntegranteRepository  extends JpaRepository<Integrante, Long> {
    
}
