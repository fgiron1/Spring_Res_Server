package com.fgiron.votosResourceServer.Models;

import java.io.Serializable;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.Entity;
import javax.persistence.Table;

/**
 *
 * @author fgiron
 */

@Entity
@Table(name = "tipos_eleccion")
public class Tipo_Eleccion implements Serializable{

    private @Id @GeneratedValue Long id;
    private String tipo_eleccion;

    public Tipo_Eleccion(){}
    
    public Tipo_Eleccion(String tipo_eleccion) {
        this.tipo_eleccion = tipo_eleccion;
    }
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getTipo_eleccion() {
        return tipo_eleccion;
    }

    public void setTipo_eleccion(String tipo_eleccion) {
        this.tipo_eleccion = tipo_eleccion;
    }

    
    
    
}
