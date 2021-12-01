package com.fgiron.votosResourceServer.Auth;

import java.io.IOException;
import java.io.InputStream;
import java.security.cert.Certificate;
import java.security.Key;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.PublicKey;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

import lombok.extern.java.Log;
import lombok.extern.log4j.Log4j;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Configuration
public class JWTSecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
          .authorizeRequests(auth -> auth
            .antMatchers(HttpMethod.GET, "/eleccion").hasAuthority("SCOPE_read")
            .antMatchers(HttpMethod.POST, "/eleccion/**").hasAuthority("SCOPE_write")
            .antMatchers(HttpMethod.POST, "/eleccion/**").hasAuthority("SCOPE_read")
            .anyRequest().authenticated())
          .oauth2ResourceServer(oauth2 -> oauth2.jwt());
	}

  @Value("${app.security.jwt.keystore-location}")
	private String keyStorePath;
	
	@Value("${app.security.jwt.keystore-password}")
	private String keyStorePassword;
	
	@Value("${app.security.jwt.key-alias}")
	private String keyAlias;
	
	@Value("${app.security.jwt.private-key-passphrase}")
	private String privateKeyPassphrase;
	
	@Bean
	public JwtHelper jwtHelper(RSAPrivateKey privateKey, RSAPublicKey publicKey){
		return new JwtHelper(privateKey, publicKey);
	}

	@Bean
	public KeyStore keyStore() {
		try {
			KeyStore keyStore = KeyStore.getInstance(KeyStore.getDefaultType());
			InputStream resourceAsStream = Thread.currentThread().getContextClassLoader().getResourceAsStream(keyStorePath);
			keyStore.load(resourceAsStream, keyStorePassword.toCharArray());
			return keyStore;
		} catch (IOException | CertificateException | NoSuchAlgorithmException | KeyStoreException e) {
			log.error("Unable to load keystore: {}", keyStorePath, e);
		}
		
		throw new IllegalArgumentException("Unable to load keystore");
	}
	
	@Bean
	public RSAPrivateKey jwtSigningKey(KeyStore keyStore) {
		try {
			Key key = keyStore.getKey(keyAlias, privateKeyPassphrase.toCharArray());
			if (key instanceof RSAPrivateKey) {
				return (RSAPrivateKey) key;
			}
		} catch (UnrecoverableKeyException | NoSuchAlgorithmException | KeyStoreException e) {
			log.error("Unable to load private key from keystore: {}", keyStorePath, e);
		}
		
		throw new IllegalArgumentException("Unable to load private key");
	}
	
	@Bean
	public RSAPublicKey jwtValidationKey(KeyStore keyStore) {
		try {
			Certificate certificate = keyStore.getCertificate(keyAlias);
			PublicKey publicKey = certificate.getPublicKey();
			
			if (publicKey instanceof RSAPublicKey) {
				return (RSAPublicKey) publicKey;
			}
		} catch (KeyStoreException e) {
			log.error("Unable to load private key from keystore: {}", keyStorePath, e);
		}
		
		throw new IllegalArgumentException("Unable to load RSA public key");
	}
	
	@Bean
	public JwtDecoder jwtDecoder(RSAPublicKey rsaPublicKey) {
		return NimbusJwtDecoder.withPublicKey(rsaPublicKey).build();
	}

}