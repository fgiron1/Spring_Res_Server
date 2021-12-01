/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Interface.java to edit this template
 */
package com.fgiron.votosResourceServer.Repositories;

import com.fgiron.votosResourceServer.Models.Voto;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.query.Procedure;

/**
 *
 * @author root
 */
public interface VotoRepository extends JpaRepository<Voto, Long>{
    
    @Procedure(procedureName = "Votar")
    public int votar(int id_elecciones,
                     int id_partido,
                     String nombre_1,
                     String nombre_2,
                     String nombre_3,
                     String apellido_1,
                     String apellido_2,
                     String apellido_3);

}
