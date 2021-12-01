package com.fgiron.votosResourceServer.Models;

import java.io.Serializable;
import java.time.ZonedDateTime;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.ManyToOne;
import javax.persistence.OneToOne;
import javax.persistence.Table;

/**
 *
 * @author fgiron
 */
@Entity
@Table(name = "Votos")
public class Voto implements Serializable{
    
    private @Id @GeneratedValue Long id;
    
    @ManyToOne(targetEntity = Eleccion.class,
            optional = false)
    private Eleccion id_eleccion;
    
    @ManyToOne(targetEntity = Voto_Partido.class,
            optional = true)
    private Voto_Partido id_partido;
    
    @ManyToOne(targetEntity = Voto_Senado.class,
            optional = true)
    private Voto_Senado id_votos_senado;
    private ZonedDateTime instante_creacion;

    public Voto(){}
    
    public Voto(Eleccion id_eleccion, Voto_Partido id_partido, Voto_Senado id_votos_senado) {
        this.id_eleccion = id_eleccion;
        this.id_partido = id_partido;
        this.id_votos_senado = id_votos_senado;
    }
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Eleccion getId_eleccion() {
        return id_eleccion;
    }

    public void setId_eleccion(Eleccion id_eleccion) {
        this.id_eleccion = id_eleccion;
    }

    public Voto_Partido getId_partido() {
        return id_partido;
    }

    public void setId_partido(Voto_Partido id_partido) {
        this.id_partido = id_partido;
    }

    public Voto_Senado getId_votos_senado() {
        return id_votos_senado;
    }

    public void setId_votos_senado(Voto_Senado id_votos_senado) {
        this.id_votos_senado = id_votos_senado;
    }

    public ZonedDateTime getInstante_creacion() {
        return instante_creacion;
    }

    public void setInstante_creacion(ZonedDateTime instante_creacion) {
        this.instante_creacion = instante_creacion;
    }
    
    
    
}
