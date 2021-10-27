package com.fgiron.votosResourceServer.Models;

import java.io.Serializable;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;
import javax.persistence.Table;

/**
 *
 * @author fgiron
 */
@Entity
@Table(name = "Votos_senado")
public class Voto_Senado implements Serializable{
    
    private @Id @GeneratedValue Long id;
    
    @ManyToOne(targetEntity = Candidato_Senado.class,
            optional = false)
    @JoinColumn(name="id_senador_1")
    private Candidato_Senado id_senador_1;
    
    @ManyToOne(targetEntity = Candidato_Senado.class,
            optional = true)
    @JoinColumn(name="id_senador_2")
    private Candidato_Senado id_senador_2;
    
    @ManyToOne(targetEntity = Candidato_Senado.class,
            optional = true)
    @JoinColumn(name="id_senador_3")
    private Candidato_Senado id_senador_3;

    public Voto_Senado(){}
    
    public Voto_Senado(Candidato_Senado id_senador_1, Candidato_Senado id_senador_2, Candidato_Senado id_senador_3) {
        this.id_senador_1 = id_senador_1;
        this.id_senador_2 = id_senador_2;
        this.id_senador_3 = id_senador_3;
    }    
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Candidato_Senado getId_senador_1() {
        return id_senador_1;
    }

    public void setId_senador_1(Candidato_Senado id_senador_1) {
        this.id_senador_1 = id_senador_1;
    }

    public Candidato_Senado getId_senador_2() {
        return id_senador_2;
    }

    public void setId_senador_2(Candidato_Senado id_senador_2) {
        this.id_senador_2 = id_senador_2;
    }

    public Candidato_Senado getId_senador_3() {
        return id_senador_3;
    }

    public void setId_senador_3(Candidato_Senado id_senador_3) {
        this.id_senador_3 = id_senador_3;
    }
    
    
    
}
