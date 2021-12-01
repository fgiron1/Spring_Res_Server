package com.fgiron.votosResourceServer.Auth;

import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class AuthController {
    
	@Autowired
    private final JwtHelper jwtHelper;

	@Autowired
	private final UserDetailsService userDetailsService;
	
	
	public AuthController(JwtHelper jwtHelper, UserDetailsService userDetailsService) {
		this.jwtHelper = jwtHelper;
		this.userDetailsService = userDetailsService;
	}
	
	@PostMapping(path = "login", consumes = { MediaType.APPLICATION_FORM_URLENCODED_VALUE })
	public LoginResult login(
			@RequestParam String username,
			@RequestParam String password) {
		
		UserDetails userDetails;
		try {
            //Carga los usuarios por DNI_hash. Debería ser DNI + id porque los DNI se repiten
			userDetails = userDetailsService.loadUserByUsername(username);
		} catch (UsernameNotFoundException e) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found");
		}
		
		if (new BCryptPasswordEncoder().matches(password, userDetails.getPassword())) {
			Map<String, String> claims = new HashMap<>();
			claims.put("username", username);
			
			String authorities = userDetails.getAuthorities().stream()
					.map(GrantedAuthority::getAuthority)
					.collect(Collectors.joining(","));
			claims.put("authorities", authorities);
			claims.put("userId", String.valueOf(1));
			
			String jwt = jwtHelper.createJwtForClaims(username, claims);
			//FALSO ERROR DE SINTAXIS
			return new LoginResult(jwt);
		}
		
		throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not authenticated");
	}
}
