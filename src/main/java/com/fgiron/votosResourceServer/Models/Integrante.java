/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Models;

import java.io.Serializable;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.ManyToOne;
import javax.persistence.Table;

/**
 *
 * @author fgiron
 */
@Entity
@Table(name = "Integrantes")
public class Integrante implements Serializable{
    
    private @Id @GeneratedValue Long id;
    private String nombre;
    private String apellidos;
    private String cargo;
    @ManyToOne(targetEntity = Voto_Partido.class,
            optional = false)
    private Voto_Partido id_partido;

    public Integrante(String nombre, String apellidos, String cargo, Voto_Partido id_partido) {
        this.nombre = nombre;
        this.apellidos = apellidos;
        this.cargo = cargo;
        this.id_partido = id_partido;
    }

    
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getApellidos() {
        return apellidos;
    }

    public void setApellidos(String apellidos) {
        this.apellidos = apellidos;
    }

    public String getCargo() {
        return cargo;
    }

    public void setCargo(String cargo) {
        this.cargo = cargo;
    }

    public Voto_Partido getId_partido() {
        return id_partido;
    }

    public void setId_partido(Voto_Partido id_partido) {
        this.id_partido = id_partido;
    }

    
    
    
    
    
}
