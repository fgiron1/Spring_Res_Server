package com.fgiron.votosResourceServer.Models;
import java.io.Serializable;
import java.time.ZonedDateTime;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.Table;
import javax.persistence.ManyToOne;

/**
 *
 * @author fgiron
 */
@Entity
@Table(name = "Elecciones")
public class Eleccion implements Serializable {
    
    private @Id @GeneratedValue Long id;
    private String provincia;
    //NOT NULL
    private ZonedDateTime instante_comienzo;
    private ZonedDateTime instante_final;
    
    @ManyToOne(targetEntity = Tipo_Eleccion.class,
            optional = false)
    @JoinColumn(name="id_tipo_eleccion")
    private Tipo_Eleccion id_tipo_eleccion;

    public Eleccion(){}
    
    public Eleccion(String provincia, ZonedDateTime instante_comienzo, ZonedDateTime instante_final, Tipo_Eleccion id_tipo_eleccion) {
        this.provincia = provincia;
        this.instante_comienzo = instante_comienzo;
        this.instante_final = instante_final;
        this.id_tipo_eleccion = id_tipo_eleccion;
    }

    
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getProvincia() {
        return provincia;
    }

    public void setProvincia(String provincia) {
        this.provincia = provincia;
    }

    public ZonedDateTime getInstante_comienzo() {
        return instante_comienzo;
    }

    public void setInstante_comienzo(ZonedDateTime instante_comienzo) {
        this.instante_comienzo = instante_comienzo;
    }

    public ZonedDateTime getInstante_final() {
        return instante_final;
    }

    public void setInstante_final(ZonedDateTime instante_final) {
        this.instante_final = instante_final;
    }

    public Tipo_Eleccion getId_tipo_eleccion() {
        return id_tipo_eleccion;
    }

    public void setId_tipo_eleccion(Tipo_Eleccion id_tipo_eleccion) {
        this.id_tipo_eleccion = id_tipo_eleccion;
    }
            
    
    
    
}
