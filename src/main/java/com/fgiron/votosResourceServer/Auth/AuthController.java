package com.fgiron.votosResourceServer.Auth;

import java.text.SimpleDateFormat;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Date;

import com.fgiron.votosResourceServer.Models_Identidades.Oauth_token;
import com.fgiron.votosResourceServer.Repositories_Identidades.Oauth_tokenRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AuthController {
    
	@Autowired
    private final JwtHelper jwtHelper;

	@Autowired
	private final UserDetailsService userDetailsService;

	@Autowired
	private final Oauth_tokenRepository token_repo;
	
	
	public AuthController(JwtHelper jwtHelper, UserDetailsService userDetailsService, Oauth_tokenRepository token_repo) {
		this.jwtHelper = jwtHelper;
		this.userDetailsService = userDetailsService;
		this.token_repo = token_repo;
	}
	
	public static boolean checkTokenPermissions(Jwt jwt, String expectedPermission){

		boolean authorized = false;

		//"exp" field in JWT represents seconds since epoch
		Instant exp_date = jwt.getClaim("exp");
		//Instant exp_date = Instant.ofEpochSecond(exp_dateLong);		
		
		//authorities es una única String que incluye todas las entidades
		//a las que el usuario puede leer o escribir.
		//Formato: entidad.write o entidad.read
		//Entidad siempre viene en plural.
		String scope = jwt.getClaimAsString("scope");

		//El token contiene el permiso esperado
		//y no ha caducado
		if(scope.contains(expectedPermission) && exp_date.isAfter(Instant.now())){
				authorized = true;
		}

		return authorized;
	}

	/*@PostMapping(path = "login", consumes = { MediaType.APPLICATION_FORM_URLENCODED_VALUE })
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
	}*/

	/*private static void registrarUsuario(String  ){
		UserDetails user1 = User
				.withUsername("user")
				.authorities("USER")
				.passwordEncoder(new BCryptPasswordEncoder()::encode)
				.password("1234")
				.build();
		
		InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();
		manager.createUser(user1);
		return manager;
	}*/
}
