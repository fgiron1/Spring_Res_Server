package com.fgiron.votosResourceServer.Models_Identidades;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Date;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "oauth_tokens")
public class Oauth_token implements Serializable {

    @Column(name="id")
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Id
    private Long id;

    @Column(name="jwt")
    private String jwt;

    @Column(name="expiration_date")
    private LocalDateTime expiration_date;

    public Oauth_token(String jwt, LocalDateTime expiration_date) {
        this.jwt = jwt;
        this.expiration_date = expiration_date;
    }


    public Oauth_token(Long id, String jwt, LocalDateTime expiration_date) {
        this.id = id;
        this.jwt = jwt;
        this.expiration_date = expiration_date;
    }


    public Oauth_token() {
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getJwt() {
        return jwt;
    }

    public void setJwt(String jwt) {
        this.jwt = jwt;
    }

    public LocalDateTime getExpiration_date() {
        return expiration_date;
    }

    public void setExpiration_date(LocalDateTime expiration_date) {
        this.expiration_date = expiration_date;
    }


}

