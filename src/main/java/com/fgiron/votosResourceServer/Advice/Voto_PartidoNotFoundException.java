package com.fgiron.votosResourceServer.Advice;

/**
 *
 * @author fgiron
 */
public class Voto_PartidoNotFoundException extends RuntimeException {
    
    public Voto_PartidoNotFoundException(Long id){
        super("No se ha podido encontrar el partido solicitado de id: " + id);
    }
    
}
