package com.fgiron.votosResourceServer.Models;

import java.io.Serializable;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.Table;

/**
 *
 * @author fgiron
 */
@Entity
@Table(name = "Candidatos_senado")
public class Candidato_Senado implements Serializable {
    
    private @GeneratedValue @Id Long id;
    private String nombre;
    private String apellidos;
    
    public Candidato_Senado(){}

    public Candidato_Senado(String nombre, String apellidos) {
        this.nombre = nombre;
        this.apellidos = apellidos;
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
    
    
    
}
