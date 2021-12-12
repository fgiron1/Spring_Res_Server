package com.fgiron.votosResourceServer.Repositories_Identidades;

import com.fgiron.votosResourceServer.Models_Identidades.Oauth_token;

import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.data.jpa.repository.JpaRepository;

//@ComponentScan(basePackageClasses = {Oauth_token.class})
@EntityScan({"com.fgiron.votosResourceServer.Models_Identidades"})
public interface Oauth_tokenRepository extends JpaRepository<Oauth_token, Long>{

    
}