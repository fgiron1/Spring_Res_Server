/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Interface.java to edit this template
 */
package com.fgiron.votosResourceServer.Repositories;

import com.fgiron.votosResourceServer.Models.Voto_Partido;

import org.springframework.data.jpa.repository.JpaRepository;

/**
 *
 * @author root
 */
public interface Voto_PartidoRepository extends JpaRepository<Voto_Partido, Long> {
    
}
