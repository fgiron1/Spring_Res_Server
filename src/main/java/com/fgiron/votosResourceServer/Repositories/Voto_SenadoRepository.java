package com.fgiron.votosResourceServer.Repositories;

import com.fgiron.votosResourceServer.Models.Voto_Senado;

import org.springframework.data.jpa.repository.JpaRepository;

/**
 *
 * @author root
 */
public interface Voto_SenadoRepository  extends JpaRepository<Voto_Senado, Long> {
    
}
