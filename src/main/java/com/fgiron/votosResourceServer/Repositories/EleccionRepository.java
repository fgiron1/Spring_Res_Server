/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Interface.java to edit this template
 */
package com.fgiron.votosResourceServer.Repositories;
import com.fgiron.votosResourceServer.Models.Eleccion;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

/**
 *
 * @author fgiron
 */
public interface EleccionRepository extends JpaRepository<Eleccion, Long> {
    
    public Eleccion getEleccionesActivas();
}
