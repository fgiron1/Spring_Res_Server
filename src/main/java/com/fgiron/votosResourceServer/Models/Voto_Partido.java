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
@Table(name = "Votos_partido")
public class Voto_Partido implements Serializable {
    
    private @Id @GeneratedValue Long id;
    private String nombre;    

    public Voto_Partido(){}
    
    public Voto_Partido(String nombre) {
        this.nombre = nombre;
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

   /* public List<Integrante> getIntegrante_list() {
        return integrante_list;
    }

    public void setIntegrante_list(List<Integrante> integrante_list) {
        this.integrante_list = integrante_list;
    }*/
    
    
    
}
