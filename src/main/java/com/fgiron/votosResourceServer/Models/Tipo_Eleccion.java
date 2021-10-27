package com.fgiron.votosResourceServer.Models;

import com.fgiron.votosResourceServer.Enums.TIPO_ELECCION;
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
    private TIPO_ELECCION tipo_eleccion;

    public Tipo_Eleccion(){}
    
    public Tipo_Eleccion(TIPO_ELECCION tipo_eleccion) {
        this.tipo_eleccion = tipo_eleccion;
    }
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public TIPO_ELECCION getTipo_eleccion() {
        return tipo_eleccion;
    }

    public void setTipo_eleccion(TIPO_ELECCION tipo_eleccion) {
        this.tipo_eleccion = tipo_eleccion;
    }

    
    
    
}
